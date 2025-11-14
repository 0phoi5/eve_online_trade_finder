#!/usr/bin/env python3
"""
compute_best_trade.py

Finds most-profitable trade runs between EVE trade hubs using your
input.csv + *_sell.csv and *_buy.csv data.  
Now color-codes console output by cargo volume:
  - < 4,300 m³  → purple background
  - 4,300–30,000 m³ → orange background
  - > 30,000 m³ → normal
"""

import csv
from pathlib import Path
from collections import defaultdict

STATIONS = ["jita", "amarr", "dodixie", "rens", "hek", "onnamon"]
SELL_FILE = "{prefix}_sell.csv"
BUY_FILE = "{prefix}_buy.csv"
BUY_FILE_RENS_ALT = "rens_but.csv"

INPUT_FILE = "input.csv"
RESULTS_FILE = "best_trades.csv"

# thresholds for color highlighting
SMALL_LOAD_M3 = 4300.0
MEDIUM_LOAD_M3 = 30000.0

# ---------- IO helpers ----------
def load_orders(file_path):
    """Return dict[item_name] -> list of (price(float), qty(int))."""
    d = defaultdict(list)
    p = Path(file_path)
    if not p.exists():
        return d
    with p.open(newline="") as f:
        r = csv.DictReader(f)
        for row in r:
            try:
                item = row["item_name"].strip()
                qty = int(float(row["quantity"]))
                price = float(row["price"])
            except Exception:
                continue
            if not item or qty <= 0 or price <= 0:
                continue
            d[item].append((price, qty))
    return d


def take_from_orders(orders, needed, cheapest=True):
    """Greedily take from orders until needed units filled."""
    arr = sorted(orders, key=lambda x: x[0], reverse=not cheapest)
    remaining = needed
    total = 0.0
    taken = 0
    breakdown = []
    for price, qty in arr:
        if remaining <= 0:
            break
        take = min(qty, remaining)
        if take <= 0:
            continue
        total += price * take
        taken += take
        remaining -= take
        breakdown.append((price, take))
    return taken, total, breakdown


def fmt_isk(x):
    return f"{x:,.2f}"


# ---------- Load input ----------
if not Path(INPUT_FILE).exists():
    raise SystemExit(f"Missing {INPUT_FILE}")

items = {}
with open(INPUT_FILE, newline="") as f:
    r = csv.DictReader(f)
    for row in r:
        try:
            name = row["item_name"].strip()
            m3 = float(row["m3"])
            cap_units = int(float(row.get("items_in_465000", "0")))
        except Exception:
            continue
        if not name:
            continue
        items[name] = {"m3": m3, "cap_units": cap_units}

# Order books
sells = {}
buys = {}
for st in STATIONS:
    sells[st] = load_orders(SELL_FILE.format(prefix=st))
    buy_file = BUY_FILE.format(prefix=st)
    if st == "rens" and not Path(buy_file).exists() and Path(BUY_FILE_RENS_ALT).exists():
        buy_file = BUY_FILE_RENS_ALT
    buys[st] = load_orders(buy_file)

# ---------- Compute best trades ----------
results = []
print(f"Loaded {len(items)} items. Scanning station pairs...")

for origin in STATIONS:
    for dest in STATIONS:
        if dest == origin:
            continue

        for item, meta in items.items():
            cap = meta["cap_units"]
            if cap <= 0:
                continue

            sell_orders = sells.get(origin, {}).get(item, [])
            buy_orders = buys.get(dest, {}).get(item, [])
            if not sell_orders or not buy_orders:
                continue

            units_buyable, cost, buy_break = take_from_orders(sell_orders, cap, cheapest=True)
            if units_buyable <= 0:
                continue

            units_sellable, revenue, sell_break = take_from_orders(
                buy_orders, units_buyable, cheapest=False
            )
            if units_sellable <= 0:
                continue

            if units_sellable < units_buyable:
                units_buyable, cost, buy_break = take_from_orders(
                    sell_orders, units_sellable, cheapest=True
                )

            if units_buyable <= 0:
                continue

            profit = revenue - cost
            if profit <= 0:
                continue

            avg_buy = cost / units_buyable
            avg_sell = revenue / units_buyable

            buy_prices = [p for p, _ in buy_break]
            sell_prices = [p for p, _ in sell_break]
            buy_min, buy_max = min(buy_prices), max(buy_prices)
            sell_min, sell_max = min(sell_prices), max(sell_prices)
            buy_count, sell_count = len(buy_break), len(sell_break)

            volume_m3 = items[item]["m3"] * units_buyable

            results.append(
                {
                    "item_name": item,
                    "origin": origin,
                    "destination": dest,
                    "units_moved": units_buyable,
                    "avg_buy_price": avg_buy,
                    "avg_sell_price": avg_sell,
                    "buy_min": buy_min,
                    "buy_max": buy_max,
                    "sell_min": sell_min,
                    "sell_max": sell_max,
                    "buy_orders": buy_count,
                    "sell_orders": sell_count,
                    "revenue": revenue,
                    "cost": cost,
                    "profit": profit,
                    "volume_m3": volume_m3,
                }
            )

# ---------- Output ----------
results.sort(key=lambda x: x["profit"], reverse=True)

with open(RESULTS_FILE, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(
        [
            "item_name",
            "origin",
            "destination",
            "units_moved",
            "avg_buy_price",
            "avg_sell_price",
            "buy_min",
            "buy_max",
            "sell_min",
            "sell_max",
            "buy_orders",
            "sell_orders",
            "revenue",
            "cost",
            "profit",
            "volume_m3",
        ]
    )
    for r in results:
        w.writerow(
            [
                r["item_name"],
                r["origin"],
                r["destination"],
                r["units_moved"],
                f"{r['avg_buy_price']:.2f}",
                f"{r['avg_sell_price']:.2f}",
                f"{r['buy_min']:.2f}",
                f"{r['buy_max']:.2f}",
                f"{r['sell_min']:.2f}",
                f"{r['sell_max']:.2f}",
                r["buy_orders"],
                r["sell_orders"],
                f"{r['revenue']:.2f}",
                f"{r['cost']:.2f}",
                f"{r['profit']:.2f}",
                f"{r['volume_m3']:.2f}",
            ]
        )

print(f"Done. Wrote {RESULTS_FILE}")
print("Top 20 opportunities:")

for r in results[:20]:
    line = (
        f"- {r['origin']} -> {r['destination']} | {r['item_name']}: {r['units_moved']} units "
        f"({r['volume_m3']:.2f} m3) | "
        f"buy {fmt_isk(r['avg_buy_price'])} (range {r['buy_min']:.2f}-{r['buy_max']:.2f}, {r['buy_orders']} orders) -> "
        f"sell {fmt_isk(r['avg_sell_price'])} (range {r['sell_min']:.2f}-{r['sell_max']:.2f}, {r['sell_orders']} orders) | "
        f"profit {fmt_isk(r['profit'])}"
    )

    vol = r["volume_m3"]
    if vol < SMALL_LOAD_M3:
        line = f"\033[45m{line}\033[0m"  # purple
    elif SMALL_LOAD_M3 <= vol <= MEDIUM_LOAD_M3:
        line = f"\033[30;43m{line}\033[0m"  # black text on orange background
    print(line)
