#!/usr/bin/env python3
"""Nile Tropical — Diagnostics #2: payment lifecycle audit (read-only).

Appends an aggregate-only section to out/REPORT.md. Run by the
"Supabase diagnostics (read-only)" workflow on GitHub's servers.

Safety:
- GET requests only (Supabase REST with the service-role key already stored
  in the repo's Actions secrets). Nothing in Supabase is changed.
- The repo is public, so this report is public. It contains counts and
  categories only: no order numbers, ids, names, phones, amounts, provider
  references or raw provider payloads. Row ids are used in memory solely to
  correlate orders with their transactions and are never written out.
- Prints nothing but a completion line to the Actions log.

Questions it answers:
  Which payment methods do the stuck orders use?
  Did the stuck orders ever get a payment transaction? What is its status?
  Did MTN run in sandbox or production for live orders?
  Are paid orders stuck before fulfilment?
"""

import collections
import datetime as dt
import json
import os
import urllib.error
import urllib.request
from pathlib import Path

REST = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/"
KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
NOW = dt.datetime.now(dt.timezone.utc)
OUT = Path("out/REPORT.md")

# Order statuses that mean fulfilment has started (or finished).
PAST_PAYMENT = {
    "payment_confirmed", "processing", "ready_for_dispatch", "dispatched",
    "out_for_delivery", "delivered", "customer_unavailable",
    "delivery_failed", "returned",
}
ONLINE = {"mtn_momo", "airtel_money", "card"}

lines = ["", "---", "", "# Diagnostics #2 — payment lifecycle", "",
         "Aggregate only. Row ids are used in memory to correlate orders and "
         "transactions and are never published.", ""]


def get(path):
    req = urllib.request.Request(
        REST + path,
        headers={"apikey": KEY, "Authorization": "Bearer " + KEY,
                 "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, None
    except Exception as e:  # network / timeout
        return type(e).__name__, None


def first_ok(*paths):
    """Try column sets from richest to simplest; schemas have drifted."""
    last = None
    for p in paths:
        code, data = get(p)
        if data is not None:
            return code, data, p
        last = code
    return last, None, None


def ts(value):
    try:
        return dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except Exception:
        return None


def age_bucket(created):
    t = ts(created)
    if t is None:
        return "unknown"
    h = (NOW - t).total_seconds() / 3600
    if h < 1:
        return "< 1h"
    if h < 24:
        return "1–24h"
    if h < 24 * 7:
        return "1–7 days"
    return "> 7 days"


def crosstab(title, rows, row_key, col_key, row_order=None):
    lines.append(f"**{title}**")
    lines.append("")
    if not rows:
        lines.append("_none_")
        lines.append("")
        return
    cols = sorted({col_key(r) for r in rows}, key=str)
    counts = collections.Counter((row_key(r), col_key(r)) for r in rows)
    rkeys = row_order or sorted({row_key(r) for r in rows}, key=str)
    lines.append("| | " + " | ".join(map(str, cols)) + " | total |")
    lines.append("|---|" + "---|" * (len(cols) + 1))
    for rk in rkeys:
        vals = [counts.get((rk, c), 0) for c in cols]
        if sum(vals):
            lines.append(f"| {rk} | " + " | ".join(map(str, vals)) + f" | {sum(vals)} |")
    lines.append("")


def counter_table(title, counter):
    lines.append(f"**{title}**")
    lines.append("")
    if not counter:
        lines.append("_none_")
        lines.append("")
        return
    lines.append("| value | count |")
    lines.append("|---|---|")
    for k, v in counter.most_common():
        lines.append(f"| {k} | {v} |")
    lines.append("")


# ── 1. Orders ───────────────────────────────────────────────────────────────
code, orders, _ = first_ok(
    "orders?select=id,status,payment_status,payment_method,created_at&limit=20000",
    "orders?select=id,status,payment_status,created_at&limit=20000",
)
if orders is None:
    lines.append(f"Could not read orders (HTTP {code}). Stopping.")
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("a") as f:
        f.write("\n".join(lines) + "\n")
    raise SystemExit(0)

for o in orders:
    o["payment_method"] = o.get("payment_method") or "(none)"

lines.append("## 1. Orders: payment method × payment status")
lines.append("")
crosstab("All orders", orders, lambda o: o["payment_method"],
         lambda o: o.get("payment_status"))

lines.append("## 2. Orders: order status × payment status")
lines.append("")
crosstab("All orders", orders, lambda o: o.get("status"),
         lambda o: o.get("payment_status"))

# ── 3. Paid but not progressed ─────────────────────────────────────────────
paid_stuck = [o for o in orders if o.get("payment_status") == "paid"
              and o.get("status") not in PAST_PAYMENT | {"cancelled"}]
lines.append("## 3. Paid but fulfilment not started")
lines.append("")
lines.append(f"Orders with payment_status = paid whose order status is still "
             f"before payment_confirmed: **{len(paid_stuck)}**")
lines.append("")
crosstab("By order status × payment method", paid_stuck,
         lambda o: o.get("status"), lambda o: o["payment_method"])
crosstab("By age", paid_stuck, lambda o: age_bucket(o.get("created_at")),
         lambda o: o["payment_method"],
         row_order=["< 1h", "1–24h", "1–7 days", "> 7 days", "unknown"])

# ── 4. Pending online payments ─────────────────────────────────────────────
pending = [o for o in orders if o.get("payment_status") == "pending"]
lines.append("## 4. Pending payments")
lines.append("")
crosstab("Age × payment method", pending,
         lambda o: age_bucket(o.get("created_at")), lambda o: o["payment_method"],
         row_order=["< 1h", "1–24h", "1–7 days", "> 7 days", "unknown"])

# ── 5. Payment transactions ────────────────────────────────────────────────
code, txs, used = first_ok(
    "payment_transactions?select=order_id,provider,method,status,created_at,"
    "env:raw_response->>payment_environment&limit=20000",
    "payment_transactions?select=order_id,provider,method,status,created_at&limit=20000",
    "payment_transactions?select=order_id,provider,status,created_at&limit=20000",
)
lines.append("## 5. Payment transactions")
lines.append("")
if txs is None:
    lines.append(f"Could not read payment_transactions (HTTP {code}).")
    lines.append("")
    txs = []
else:
    lines.append(f"Total transactions: **{len(txs)}**")
    lines.append("")
    for t in txs:
        t["provider"] = t.get("provider") or "(none)"
        t["method"] = t.get("method") or "(none)"
        t["env"] = (t.get("env") or "(not recorded)") if "env:" in (used or "") else "(not queried)"
    crosstab("Provider / method × transaction status", txs,
             lambda t: f'{t["provider"]} / {t["method"]}', lambda t: t.get("status"))
    crosstab("MTN environment × transaction status (sandbox cannot settle real money)",
             [t for t in txs if "mtn" in t["provider"]], lambda t: t["env"],
             lambda t: t.get("status"))

# ── 6. Stuck orders ↔ transactions ─────────────────────────────────────────
by_order = collections.defaultdict(list)
for t in txs:
    if t.get("order_id"):
        by_order[t["order_id"]].append(t)


def latest_tx(order_id):
    ts_list = by_order.get(order_id) or []
    if not ts_list:
        return None
    return max(ts_list, key=lambda t: ts(t.get("created_at")) or NOW)


stuck = [o for o in pending
         if age_bucket(o.get("created_at")) in ("1–7 days", "> 7 days")]
lines.append("## 6. Pending > 24h: what happened to their payment attempt?")
lines.append("")
lines.append(f"Orders pending for more than 24 hours: **{len(stuck)}**")
lines.append("")


def outcome(o):
    t = latest_tx(o["id"])
    if t is None:
        if o["payment_method"] in ("airtel_money", "card"):
            return "no transaction — provider not configured"
        return "no transaction — payment never initiated"
    env = t.get("env", "")
    env = f", {env}" if env and not env.startswith("(") else ""
    return f'latest tx: {t.get("status")}{env}'


crosstab("Outcome × payment method", stuck, outcome,
         lambda o: o["payment_method"])

tx_counts = collections.Counter(len(by_order.get(o["id"], [])) for o in stuck)
counter_table("Number of transactions per stuck order",
              collections.Counter({f"{k} tx": v for k, v in tx_counts.items()}))

# ── 7. Transaction says success but order not paid (reconciliation gap) ────
SUCCESS = {"successful", "success", "succeeded", "paid", "completed"}
gap = [o for o in orders if o.get("payment_status") != "paid"
       and any(str(t.get("status")).lower() in SUCCESS for t in by_order.get(o["id"], []))]
lines.append("## 7. Reconciliation gap")
lines.append("")
lines.append(f"Orders not marked paid although a transaction reports success: **{len(gap)}**")
lines.append("")
if gap:
    crosstab("By order status × payment status", gap, lambda o: o.get("status"),
             lambda o: o.get("payment_status"))

# ── 8. Data API accessibility of payment tables ────────────────────────────
lines.append("## 8. REST (Data API) accessibility")
lines.append("")
lines.append("| resource | HTTP |")
lines.append("|---|---|")
for res in ("orders", "payments", "payment_transactions", "order_status_history",
            "notification_queue", "notifications"):
    c, _ = get(f"{res}?select=*&limit=0")
    lines.append(f"| {res} | {c if c != 200 else '200 (readable)'} |")
lines.append("")
lines.append("404 means the table is absent or not exposed to the Data API; "
             "it does not by itself mean there are no rows.")

OUT.parent.mkdir(exist_ok=True)
with OUT.open("a") as f:
    f.write("\n".join(lines) + "\n")
print("Diagnostics #2 appended (contents not printed to the public log).")
