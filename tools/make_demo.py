"""Generate web/data/demo.json: one realistic month for Sheela, a home food seller in Kozhikode.

Run from the repo root:  python tools/make_demo.py
Numbers are an EXAMPLE, not a real person. Replace with real numbers from the women we spoke to.
"""
import json
import random
from datetime import date, timedelta

random.seed(7)  # same output every run

TODAY = date(2026, 10, 23)
MONTH = TODAY.strftime("%Y-%m")

products = [
    {"id": "p1", "name_ml": "ബിരിയാണി", "name_en": "Biriyani", "price": 100},
    {"id": "p2", "name_ml": "ചപ്പാത്തി", "name_en": "Chapathi", "price": 8},
    {"id": "p3", "name_ml": "പൊറോട്ട", "name_en": "Parotta", "price": 12},
    {"id": "p4", "name_ml": "അച്ചാർ കുപ്പി", "name_en": "Pickle bottle", "price": 120},
]

# Typical daily quantity range per product (Sundays are busier).
daily = {"p1": (7, 13), "p2": (30, 50), "p3": (20, 35), "p4": (0, 2)}

bills = [
    {"id": "b1", "month": MONTH, "type": "gas", "label_ml": "ഗ്യാസ്", "label_en": "Gas", "amount": 1800},
    {"id": "b2", "month": MONTH, "type": "electricity", "label_ml": "കറന്റ്", "label_en": "Electricity", "amount": 650},
    {"id": "b3", "month": MONTH, "type": "transport", "label_ml": "യാത്ര", "label_en": "Transport", "amount": 900},
    {"id": "b4", "month": MONTH, "type": "phone", "label_ml": "ഫോൺ", "label_en": "Phone", "amount": 299},
    {"id": "b5", "month": MONTH, "type": "emi", "label_ml": "മിക്സി ഇഎംഐ", "label_en": "Mixer EMI", "amount": 1200, "due_day": 5},
]

# Stock bought this month. gst = the GST amount printed on the shop bill (0 for loose rice, chicken).
purchases = [
    {"id": "u1", "date": f"{MONTH}-01", "item": "Rice", "item_ml": "അരി", "qty": 25, "unit": "kg", "amount": 1450, "gst": 0},
    {"id": "u2", "date": f"{MONTH}-01", "item": "Cooking oil", "item_ml": "എണ്ണ", "qty": 5, "unit": "L", "amount": 900, "gst": 43},
    {"id": "u3", "date": f"{MONTH}-02", "item": "Wheat flour (atta)", "item_ml": "ആട്ട", "qty": 20, "unit": "kg", "amount": 960, "gst": 46},
    {"id": "u4", "date": f"{MONTH}-02", "item": "Maida", "item_ml": "മൈദ", "qty": 20, "unit": "kg", "amount": 880, "gst": 42},
    {"id": "u5", "date": f"{MONTH}-03", "item": "Chicken", "item_ml": "ചിക്കൻ", "qty": 24, "unit": "kg", "amount": 4800, "gst": 0},
    {"id": "u6", "date": f"{MONTH}-10", "item": "Chicken", "item_ml": "ചിക്കൻ", "qty": 24, "unit": "kg", "amount": 4900, "gst": 0},
    {"id": "u7", "date": f"{MONTH}-17", "item": "Chicken", "item_ml": "ചിക്കൻ", "qty": 22, "unit": "kg", "amount": 4700, "gst": 0},
    {"id": "u8", "date": f"{MONTH}-05", "item": "Spices + masala", "item_ml": "മസാല", "qty": 1, "unit": "lot", "amount": 1300, "gst": 62},
    {"id": "u9", "date": f"{MONTH}-05", "item": "Packaging boxes + covers", "item_ml": "പാക്കിംഗ്", "qty": 1, "unit": "lot", "amount": 1500, "gst": 160},
    {"id": "u10", "date": f"{MONTH}-12", "item": "Pickle bottles", "item_ml": "കുപ്പി", "qty": 40, "unit": "pcs", "amount": 800, "gst": 96},
    {"id": "u11", "date": f"{MONTH}-15", "item": "Rice", "item_ml": "അരി", "qty": 10, "unit": "kg", "amount": 600, "gst": 0},
]

# Daily sales from the 1st up to yesterday. Today is left empty so the demo call fills it.
sales = []
n = 1
d = date(TODAY.year, TODAY.month, 1)
while d < TODAY:
    busy = 1.3 if d.weekday() == 6 else 1.0
    for pid, (lo, hi) in daily.items():
        qty = round(random.randint(lo, hi) * busy)
        if qty:
            sales.append({"id": f"s{n}", "date": d.isoformat(), "product": pid, "qty": qty, "via": "app"})
            n += 1
    d += timedelta(days=1)

# Earlier months of this financial year (April onwards), as monthly totals.
# June is the slow month (monsoon).
history = [
    {"id": "2026-04", "month": "2026-04", "income": 41200, "spending": 27100, "gst_paid": 410},
    {"id": "2026-05", "month": "2026-05", "income": 43800, "spending": 28300, "gst_paid": 430},
    {"id": "2026-06", "month": "2026-06", "income": 31500, "spending": 25900, "gst_paid": 380},
    {"id": "2026-07", "month": "2026-07", "income": 38900, "spending": 26800, "gst_paid": 420},
    {"id": "2026-08", "month": "2026-08", "income": 46100, "spending": 29400, "gst_paid": 450},
    {"id": "2026-09", "month": "2026-09", "income": 47300, "spending": 29900, "gst_paid": 460},
]

goals = [
    {"id": "g1", "name_ml": "ഓട്ടോ", "name_en": "Auto rickshaw (down payment)", "target": 40000, "saved": 24000, "monthly": 5000},
]

demo = {
    "_note": "EXAMPLE data for the demo user Sheela. Not a real person.",
    "user": {"name": "Sheela", "name_ml": "ഷീല", "place": "Kozhikode", "place_ml": "കോഴിക്കോട്", "lang": "ml"},
    "products": products,
    "bills": bills,
    "purchases": purchases,
    "sales": sales,
    "history": history,
    "goals": goals,
    "bulk_requests": [
        {"id": "r1", "user": "demo1", "name": "Sheela", "month": "2026-11", "item": "Rice", "item_ml": "അരി", "qty": 30, "unit": "kg", "place": "Kozhikode"},
        {"id": "r2", "user": "demo2", "name": "Ramla", "month": "2026-11", "item": "Rice", "item_ml": "അരി", "qty": 25, "unit": "kg", "place": "Kozhikode"},
        {"id": "r3", "user": "demo3", "name": "Bindu", "month": "2026-11", "item": "Rice", "item_ml": "അരി", "qty": 25, "unit": "kg", "place": "Kozhikode"},
        {"id": "r4", "user": "demo4", "name": "Safiya", "month": "2026-11", "item": "Rice", "item_ml": "അരി", "qty": 30, "unit": "kg", "place": "Kozhikode"},
        {"id": "r5", "user": "demo2", "name": "Ramla", "month": "2026-11", "item": "Cooking oil", "item_ml": "എണ്ണ", "qty": 10, "unit": "L", "place": "Kozhikode"},
        {"id": "r6", "user": "demo5", "name": "Lissy", "month": "2026-11", "item": "Cooking oil", "item_ml": "എണ്ണ", "qty": 5, "unit": "L", "place": "Kozhikode"},
    ],
}

with open("web/data/demo.json", "w", encoding="utf-8") as f:
    json.dump(demo, f, ensure_ascii=False, indent=1)

income = sum(s["qty"] * next(p["price"] for p in products if p["id"] == s["product"]) for s in sales)
spending = sum(b["amount"] for b in bills) + sum(p["amount"] for p in purchases)
print(f"sales entries: {len(sales)}  income so far: {income}  spending: {spending}  profit: {income - spending}")
