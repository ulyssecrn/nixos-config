"""Import config for the beancount ledger (Boursobank and Chase CSV exports).

Fava loads this as /etc/beancount/import.py (see services/beancount.nix). The
same file runs offline for a backlog, which keeps minutes of LLM calls out of
a Fava HTTP request:

    python3 import.py extract -e main.beancount -o out.beancount FILE...

Everything personal (account numbers, merchant rules, the owner's context for
the LLM) lives in import_rules.py next to the ledger, not in this public repo;
BEANCOUNT_RULES points elsewhere for offline runs.

Hooks run in order on transactions that still have a single posting:
deterministic rules, then the LLM on genghis, then smart_importer as the
offline fallback. Anything not decided by a rule gets the '!' flag unless the
LLM says it is confident, so '!' transactions are the review queue. Only
'*' transactions are used as few-shot examples, so reviewing is how
corrections get learned.
"""

from __future__ import annotations

import csv
import datetime
import json
import logging
import os
import re
import runpy
import urllib.request
from decimal import Decimal

import beangulp
from beancount.core import data
from beancount.core.amount import Amount
from beangulp import Importer
from smart_importer import PredictPostings

log = logging.getLogger("beancount-import")

# Rows before this are skipped; a history backfill runs offline with an
# earlier BEANCOUNT_START.
LEDGER_START = datetime.date.fromisoformat(os.environ.get("BEANCOUNT_START", "2026-01-01"))
ONE_DAY = datetime.timedelta(days=1)

LLM_URL = "http://10.10.10.9:8080/v1/chat/completions"
LLM_BATCH = 40
LLM_TIMEOUT = 600

PRIVATE = runpy.run_path(os.environ.get("BEANCOUNT_RULES", "/var/lib/beancount/import_rules.py"))


def _clean(text: str) -> str:
    return " ".join(text.split())


def _posting(account: str, units: Amount | None = None) -> data.Posting:
    return data.Posting(account, units, None, None, None, None)


def _txn(meta, date, payee, narration, account, units) -> data.Transaction:
    return data.Transaction(
        meta, date, "*", payee, narration, data.EMPTY_SET, data.EMPTY_SET,
        [_posting(account, units)],
    )


def _fr_decimal(text: str) -> Decimal:
    # "1 000,00", sometimes with a (narrow) no-break space as the separator.
    return Decimal(re.sub(r"[\s  ]", "", text).replace(",", "."))


def _same_row(new: data.Directive, old: data.Directive) -> bool:
    # beangulp's default comparator accepts amounts within 5% two days apart,
    # which took a -8.00 bar tab for a -7.92 subscription. Overlapping bank
    # exports repeat a row exactly, so require exactly that.
    if not (isinstance(new, data.Transaction) and isinstance(old, data.Transaction)):
        return False
    own = new.postings[0]
    return new.date == old.date and new.narration == old.narration and any(
        p.account == own.account and p.units == own.units for p in old.postings
    )


class Boursobank(Importer):
    """Boursobank current-account CSV ("Exporter mes opérations")."""

    HEADER = '"Date Opération";"Date Valeur";Libellé;'
    cmp = staticmethod(_same_row)

    def __init__(self, accounts: dict[str, str]):
        self.ACCOUNTS = accounts

    # Two columns are both named "Solde" (the amount, then the running
    # balance), so rows are read by position.
    DATE, LABEL, SUGGESTED, CATEGORY, PARENT, AMOUNT, ACCOUNT, BALANCE = (
        0, 2, 3, 4, 5, 6, 8, 10,
    )

    @property
    def name(self) -> str:
        return "boursobank"

    def _rows(self, filepath: str) -> list[list[str]]:
        with open(filepath, encoding="utf-8-sig", newline="") as f:
            rows = list(csv.reader(f, delimiter=";"))
        return [row for row in rows[1:] if row]

    def identify(self, filepath: str) -> bool:
        if not filepath.lower().endswith(".csv"):
            return False
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            return f.readline().startswith(self.HEADER)

    def account(self, filepath: str) -> str:
        rows = self._rows(filepath)
        return self.ACCOUNTS.get(rows[0][self.ACCOUNT], "") if rows else ""

    def date(self, filepath: str) -> datetime.date | None:
        rows = self._rows(filepath)
        return max((datetime.date.fromisoformat(r[self.DATE]) for r in rows), default=None)

    def extract(self, filepath: str, existing: data.Directives) -> data.Directives:
        entries: data.Directives = []
        newest: dict[str, tuple[datetime.date, Decimal]] = {}
        for lineno, row in enumerate(self._rows(filepath), start=2):
            number = row[self.ACCOUNT]
            if number not in self.ACCOUNTS:
                raise ValueError(f"unknown Boursobank account {number!r}: add it to BOURSO_ACCOUNTS")
            account = self.ACCOUNTS[number]
            date = datetime.date.fromisoformat(row[self.DATE])
            # Rows are newest first and the running balance is end of day on
            # the newest date, so the first row per account gives the check.
            newest.setdefault(account, (date, Decimal(row[self.BALANCE])))
            if date < LEDGER_START:
                continue
            label = _clean(row[self.LABEL])
            # Bourso's suggested label is a clean merchant name for card and
            # direct-debit lines, and noise for transfers.
            payee = None
            if label.startswith(("CARTE ", "PRLV ", "AVOIR ")):
                payee = _clean(row[self.SUGGESTED]) or None
            meta = data.new_metadata(filepath, lineno, {"category": row[self.CATEGORY]})
            entries.append(_txn(
                meta, date, payee, label, account,
                Amount(_fr_decimal(row[self.AMOUNT]), "EUR"),
            ))
        for account, (date, balance) in newest.items():
            meta = data.new_metadata(filepath, 0)
            entries.append(data.Balance(meta, date + ONE_DAY, account, Amount(balance, "EUR"), None, None))
        return entries


class Chase(Importer):
    """Chase checking CSV ("Download account activity")."""

    HEADER = "Details,Posting Date,Description,Amount,Type,Balance,"
    cmp = staticmethod(_same_row)

    def __init__(self, account: str):
        self._account = account

    @property
    def name(self) -> str:
        return "chase"

    def _rows(self, filepath: str) -> list[dict[str, str]]:
        with open(filepath, encoding="utf-8-sig", newline="") as f:
            return list(csv.DictReader(f))

    def identify(self, filepath: str) -> bool:
        if not filepath.lower().endswith(".csv"):
            return False
        with open(filepath, encoding="utf-8-sig", errors="replace") as f:
            return f.readline().startswith(self.HEADER)

    def account(self, filepath: str) -> str:
        return self._account

    @staticmethod
    def _date(row: dict[str, str]) -> datetime.date:
        return datetime.datetime.strptime(row["Posting Date"], "%m/%d/%Y").date()

    def date(self, filepath: str) -> datetime.date | None:
        return max((self._date(r) for r in self._rows(filepath)), default=None)

    def extract(self, filepath: str, existing: data.Directives) -> data.Directives:
        entries: data.Directives = []
        newest = None
        for lineno, row in enumerate(self._rows(filepath), start=2):
            # Pending card holds have no running balance yet and come back
            # later as a posted DEBIT_CARD row with a different description.
            if not row["Balance"].strip():
                continue
            date = self._date(row)
            if newest is None:
                newest = (date, Decimal(row["Balance"]))
            if date < LEDGER_START:
                continue
            description = _clean(row["Description"])
            # Card lines end with the purchase date ("... NY 10/31"), wires
            # carry a 300-char routing blob after the useful part.
            description = re.sub(r"\s+\d{2}/\d{2}$", "", description)
            if row["Type"] == "WIRE_INCOMING":
                description = description.split(" REF:")[0]
            meta = data.new_metadata(filepath, lineno)
            entries.append(_txn(
                meta, date, None, description, self._account,
                Amount(Decimal(row["Amount"]), "USD"),
            ))
        if newest:
            date, balance = newest
            meta = data.new_metadata(filepath, 0)
            entries.append(data.Balance(meta, date + ONE_DAY, self._account, Amount(balance, "USD"), None, None))
        return entries


# --- classification -------------------------------------------------------

# (imported account prefix, narration regex, amount predicate or None, target)
RULES = PRIVATE["RULES"]

# Unlike its merchant guesses, Boursobank's tag for transfers between the
# owner's own accounts is structural and reliable, and catches transfers the
# owner relabelled by hand ("VIR Remboursement Maman TGV").
INTERNAL_CATEGORIES = {
    "Virements émis de comptes à comptes",
    "Virements reçus de comptes à comptes",
    "Mouvements internes débiteurs",
    "Mouvements internes créditeurs",
}

def _pending(entries: data.Directives) -> list[tuple[int, data.Transaction]]:
    return [
        (i, e) for i, e in enumerate(entries)
        if isinstance(e, data.Transaction) and len(e.postings) == 1
        # Rows already in the ledger (overlapping exports) aren't saved, so
        # don't spend LLM calls on them.
        and not e.meta.get("__duplicate__")
    ]


def _assign(txn: data.Transaction, account: str, flag: str) -> data.Transaction:
    return txn._replace(flag=flag, postings=[*txn.postings, _posting(account)])


def rules_hook(
    imported: list[tuple[str, data.Directives, str, Importer]],
    existing: data.Directives,
) -> list[tuple[str, data.Directives, str, Importer]]:
    result = []
    for filename, entries, account, importer in imported:
        entries = list(entries)
        for i, txn in _pending(entries):
            own = txn.postings[0]
            target = None
            for prefix, pattern, predicate, dest in RULES:
                if not own.account.startswith(prefix) or not re.search(pattern, txn.narration):
                    continue
                if predicate and not predicate(own.units.number):
                    continue
                target = dest
                break
            if target is None and txn.meta.get("category") in INTERNAL_CATEGORIES:
                target = "Assets:Transit"
            if target:
                entries[i] = _assign(txn, target, "*")
        result.append((filename, entries, account, importer))
    return result


# --- EUR -> USD wires --------------------------------------------------------
# A Boursobank -> Chase wire arrives as two transactions, one per CSV, both
# against Assets:Transit: +EUR from Bourso, -USD from Chase. A conversion
# entry pairs them at the ECB reference rate (from the USD price that the
# beancount-prices timer fetches), which empties Transit and leaves the bank's
# FX margin in Expenses:Banking:FX.

WIRE_EUR = re.compile(PRIVATE["WIRE_EUR"])
WIRE_USD = re.compile(PRIVATE["WIRE_USD"])
FX_ACCOUNT = "Expenses:Banking:FX"
# Chase has credited a wire up to 3 days before Bourso dated the debit.
WIRE_WINDOW = datetime.timedelta(days=4)
# Bank rates seen in 2026 were 0.5-1.4% under ECB; a pairing outside this band
# is the wrong pair, not a bad rate.
WIRE_MARGIN = (Decimal("-0.005"), Decimal("0.04"))


def _wire_legs(entries: data.Directives) -> list[tuple[datetime.date, Decimal]]:
    legs = []
    for e in entries:
        if isinstance(e, data.Transaction) and WIRE_EUR.match(e.narration) \
                and not e.meta.get("__duplicate__"):
            for p in e.postings:
                if p.account.startswith("Assets:Boursobank:") and p.units.currency == "EUR":
                    legs.append((e.date, -p.units.number))
    return legs


def _converted(entries: data.Directives) -> set[tuple[datetime.date, Decimal]]:
    done = set()
    for e in entries:
        if isinstance(e, data.Transaction) and "eur-date" in e.meta:
            for p in e.postings:
                if p.account == "Assets:Transit" and p.units.currency == "EUR":
                    done.add((e.meta["eur-date"], -p.units.number))
    return done


def _ecb_rates(entries: data.Directives) -> list[tuple[datetime.date, Decimal]]:
    rates = {}
    for e in entries:
        if isinstance(e, data.Price) and e.currency == "USD" and e.amount.currency == "EUR":
            rates[e.date] = (1 / e.amount.number).quantize(Decimal("0.0001"))
    return sorted(rates.items())


def _rate_on(rates: list[tuple[datetime.date, Decimal]], date: datetime.date) -> Decimal | None:
    found = None
    for d, r in rates:
        if d > date:
            break
        found = r
    return found


def wire_conversions(
    usd_wires: list[data.Transaction], entries: data.Directives,
) -> list[data.Transaction]:
    """Pair each Chase wire with its Bourso debit and book the conversion."""
    rates = _ecb_rates(entries)
    done = _converted(entries)
    open_legs = [leg for leg in _wire_legs(entries) if leg not in done]
    out = []
    for txn in sorted(usd_wires, key=lambda t: t.date):
        usd = txn.postings[0].units.number
        best = None
        for leg in open_legs:
            eur_date, eur = leg
            rate = _rate_on(rates, eur_date)
            if rate is None or abs(eur_date - txn.date) > WIRE_WINDOW:
                continue
            margin = 1 - usd / (eur * rate)
            if WIRE_MARGIN[0] <= margin <= WIRE_MARGIN[1] and (best is None or margin < best[0]):
                best = (margin, leg, rate)
        if best is None:
            log.warning("no Boursobank debit found for the %s USD wire of %s", usd, txn.date)
            continue
        _, leg, rate = best
        open_legs.remove(leg)
        eur_date, eur = leg
        meta = data.new_metadata("<wire_conversions>", 0, {"eur-date": eur_date})
        out.append(data.Transaction(
            meta, max(txn.date, eur_date), "*", None,
            "Change EUR→USD, virement Boursobank → Chase", data.EMPTY_SET, data.EMPTY_SET,
            [
                data.Posting("Assets:Transit", Amount(-eur, "EUR"), None, Amount(rate, "USD"), None, None),
                _posting("Assets:Transit", Amount(usd, "USD")),
                _posting(FX_ACCOUNT),
            ],
        ))
    return out


def fx_hook(
    imported: list[tuple[str, data.Directives, str, Importer]],
    existing: data.Directives,
) -> list[tuple[str, data.Directives, str, Importer]]:
    # Bourso legs can come from the ledger or from a Bourso CSV imported in
    # the same run.
    pool = list(existing) + [e for _, entries, _, _ in imported for e in entries]
    result = []
    for filename, entries, account, importer in imported:
        wires = [
            e for e in entries
            if isinstance(e, data.Transaction) and WIRE_USD.match(e.narration)
            and not e.meta.get("__duplicate__")
        ]
        conversions = wire_conversions(wires, pool) if wires else []
        pool += conversions
        result.append((filename, [*entries, *conversions], account, importer))
    return result


_TOKEN = re.compile(r"[a-z][a-z0-9'&.-]{2,}")


def _tokens(txn: data.Transaction) -> set[str]:
    return set(_TOKEN.findall(f"{txn.payee or ''} {txn.narration}".lower()))


def _category_account(txn: data.Transaction) -> str | None:
    accounts = [p.account for p in txn.postings if p.account.startswith(("Expenses:", "Income:"))]
    return accounts[0] if len(accounts) == 1 else None


def _describe(txn: data.Transaction) -> dict:
    own = txn.postings[0]
    return {
        "date": txn.date.isoformat(),
        "account": own.account,
        "amount": f"{own.units.number} {own.units.currency}" if own.units else None,
        "payee": txn.payee,
        "description": txn.narration,
        **({"bank_category": txn.meta["category"]} if txn.meta.get("category") else {}),
    }


SYSTEM_PROMPT = f"""\
You categorise bank transactions for a personal double-entry ledger.
Negative amounts are money out.

{PRIVATE["OWNER_NOTES"]}
Rules:
- Pick exactly one account per transaction, only from the allowed list.
- Refunds from a merchant go to that merchant's expense account.
- "bank_category" is the bank's automatic guess and is often wrong. Use it
  only as a weak hint when the merchant name tells you nothing; never mark a
  guess confident on it alone.
- Follow the owner's past categorisations in the examples when a merchant
  matches; they override your own judgement.
- Set "confident" to false when the merchant is unknown or ambiguous.
- Use Expenses:Uncategorized only when nothing fits.
"""


def _llm(batch: list[dict], examples: list[dict], accounts: list[str]) -> dict[int, tuple[str, bool]]:
    schema = {
        "type": "object",
        "properties": {
            "results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        "account": {"type": "string", "enum": accounts},
                        "confident": {"type": "boolean"},
                    },
                    "required": ["id", "account", "confident"],
                },
            }
        },
        "required": ["results"],
    }
    user = (
        "Allowed accounts:\n" + "\n".join(accounts)
        + "\n\nPast categorisations by the owner:\n"
        + (json.dumps(examples, ensure_ascii=False, indent=0) if examples else "(none yet)")
        + "\n\nCategorise these transactions:\n"
        + json.dumps(batch, ensure_ascii=False, indent=0)
    )
    body = {
        "model": "local",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user},
        ],
        "temperature": 0,
        "max_tokens": 60 * len(batch) + 200,
        # The server defaults to thinking, which spends the whole token budget
        # before any content is emitted.
        "chat_template_kwargs": {"enable_thinking": False},
        "response_format": {"type": "json_schema", "json_schema": {"name": "categories", "schema": schema}},
    }
    request = urllib.request.Request(
        LLM_URL, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=LLM_TIMEOUT) as response:
        reply = json.load(response)
    content = json.loads(reply["choices"][0]["message"]["content"])
    return {r["id"]: (r["account"], r["confident"]) for r in content["results"]}


def llm_hook(
    imported: list[tuple[str, data.Directives, str, Importer]],
    existing: data.Directives,
) -> list[tuple[str, data.Directives, str, Importer]]:
    opened = {e.account for e in existing if isinstance(e, data.Open)}
    closed = {e.account for e in existing if isinstance(e, data.Close)}
    accounts = sorted(
        a for a in opened - closed if a.startswith(("Expenses:", "Income:"))
    )
    if not accounts:
        return imported
    history = [
        (e, _tokens(e), acct)
        for e in existing
        if isinstance(e, data.Transaction) and e.flag == "*"
        and (acct := _category_account(e)) is not None
    ]

    result = []
    for filename, entries, account, importer in imported:
        entries = list(entries)
        pending = _pending(entries)
        for start in range(0, len(pending), LLM_BATCH):
            chunk = pending[start:start + LLM_BATCH]
            examples: dict[int, dict] = {}
            for _, txn in chunk:
                words = _tokens(txn)
                if not words:
                    continue
                scored = sorted(
                    ((len(words & w) / len(words | w), id(e), e, a) for e, w, a in history if words & w),
                    key=lambda s: s[0], reverse=True,
                )
                for _, key, e, a in scored[:3]:
                    examples[key] = {**_describe(e), "category": a}
            batch = [{"id": n, **_describe(txn)} for n, (_, txn) in enumerate(chunk)]
            try:
                answers = _llm(batch, list(examples.values())[:80], accounts)
            except Exception:
                log.exception("LLM categorisation failed; leaving %d transactions to smart_importer", len(chunk))
                continue
            for n, (i, txn) in enumerate(chunk):
                if n in answers:
                    target, confident = answers[n]
                    if target in accounts:
                        flag = "*" if confident and target != "Expenses:Uncategorized" else "!"
                        entries[i] = _assign(txn, target, flag)
        result.append((filename, entries, account, importer))
    return result


_smart = PredictPostings()
_MARK = "__smart__"


def smart_hook(
    imported: list[tuple[str, data.Directives, str, Importer]],
    existing: data.Directives,
) -> list[tuple[str, data.Directives, str, Importer]]:
    # smart_importer doesn't report what it filled in, so the candidates are
    # tagged going in and whatever comes back with a second posting is
    # flagged for review.
    marked = []
    for filename, entries, account, importer in imported:
        entries = list(entries)
        for i, txn in _pending(entries):
            entries[i] = txn._replace(meta={**txn.meta, _MARK: True})
        marked.append((filename, entries, account, importer))

    result = []
    for filename, entries, account, importer in _smart.hook(marked, existing):
        out = []
        for e in entries:
            if isinstance(e, data.Transaction) and _MARK in e.meta:
                meta = {k: v for k, v in e.meta.items() if k != _MARK}
                e = e._replace(meta=meta, flag="!" if len(e.postings) > 1 else e.flag)
            out.append(e)
        result.append((filename, out, account, importer))
    return result


CONFIG = [
    Boursobank(PRIVATE["BOURSO_ACCOUNTS"]),
    Chase(PRIVATE["CHASE_ACCOUNT"]),
]

HOOKS = [rules_hook, fx_hook, llm_hook, smart_hook]


if __name__ == "__main__":
    beangulp.Ingest(CONFIG, HOOKS)()
