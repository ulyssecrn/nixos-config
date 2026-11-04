"""Print an EUR price for every USD price that lacks one on the same day.

US stocks are bought from a EUR account, so their cost basis is EUR while
their quotes come in USD. Beancount's value() and Fava's market-value views
look up commodity -> cost currency directly and never chain through USD, so
without a direct EUR price those holdings are valued at nonsense.
"""

import sys
from decimal import Decimal

from beancount import loader
from beancount.core import data, prices

entries, _, _ = loader.load_file(sys.argv[1])
price_map = prices.build_price_map(entries)

have_eur = {
    (e.currency, e.date)
    for e in entries
    if isinstance(e, data.Price) and e.amount.currency == "EUR"
}

for e in entries:
    if not isinstance(e, data.Price) or e.amount.currency != "USD":
        continue
    if e.currency == "EUR" or (e.currency, e.date) in have_eur:
        continue
    _, rate = prices.get_price(price_map, ("USD", "EUR"), e.date)
    if rate is None:
        continue
    eur = (e.amount.number * rate).quantize(Decimal("0.0001"))
    print(f"{e.date} price {e.currency} {eur} EUR")
    have_eur.add((e.currency, e.date))
