"""Beancount plugin: repeat a transaction every month.

A transaction carrying `repeat-until: YYYY-MM-DD` is copied to the same day of
each following month up to that date, but never past today. A lease share or a
prepaid plan then lands in the month it covers, one month at a time, without a
hand-written entry per month.

Loaded from the ledger directory (`option "insert_pythonpath" "TRUE"` and
`plugin "recurring"` in main.beancount).
"""

import collections
import datetime

from beancount.core import data

__plugins__ = ["recurring"]

RecurringError = collections.namedtuple("RecurringError", "source message entry")


def _next_month(day):
    year, month = divmod(day.month, 12)
    return day.replace(year=day.year + year, month=month + 1)


def recurring(entries, options_map):
    today = datetime.date.today()
    copies, errors = [], []
    for entry in entries:
        if not isinstance(entry, data.Transaction) or "repeat-until" not in entry.meta:
            continue
        until = entry.meta["repeat-until"]
        # Months have 28 days at least; a template on the 29th-31st would
        # silently drift or fail in February.
        if not isinstance(until, datetime.date) or entry.date.day > 28:
            errors.append(RecurringError(entry.meta, "repeat-until needs a date and a template on day 1-28", entry))
            continue
        day = _next_month(entry.date)
        while day <= min(until, today):
            copies.append(entry._replace(date=day))
            day = _next_month(day)
    return sorted(entries + copies, key=data.entry_sortkey), errors
