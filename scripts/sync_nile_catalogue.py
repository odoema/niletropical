#!/usr/bin/env python3
"""Patch existing catalogue copy and insert high-confidence new SKUs."""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"{name} is missing")
    return value.rstrip("/")


def api(method: str, path: str, body=None, prefer: str = "return=representation"):
    url = f"{SUPABASE_URL}{path}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {SERVICE_KEY}",
        "apikey": SERVICE_KEY,
        "Accept": "application/json",
    }
    if body is not None:
        headers["Content-Type"] = "application/json"
        headers["Prefer"] = prefer
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode("utf-8") or "[]"
            if not raw.strip():
                return []
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"{method} {path} -> HTTP {exc.code}: {detail}") from exc


def normalize(text: str) -> str:
    text = text.lower().strip()
    text = text.replace("&", " and ")
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def match_category(categories, hints):
    if not categories or not hints:
        return None
    hint_norms = [normalize(h) for h in hints if h]
    for cat in categories:
        slug = normalize(str(cat.get("slug") or ""))
        name = normalize(str(cat.get("name") or ""))
        if slug in hint_norms or name in hint_norms:
            cat_id = str(cat.get("id") or "")
            if UUID_RE.match(cat_id):
                return cat_id
    return None


def patch_existing(catalog: dict) -> None:
    print("=== Updating product copy ===")
    for slug, item in catalog.items():
        if slug.startswith("_") or not isinstance(item, dict):
            continue
        rows = api("GET", f"/rest/v1/products?select=id&slug=eq.{urllib.parse.quote(slug)}&limit=1")
        if not rows:
            print(f"::warning::Product slug not found in production: {slug} — skipping copy update.")
            continue
        payload = {
            "name": item.get("name") or slug,
            "short_description": item.get("description") or "",
            "full_description": item.get("description") or "",
        }
        if item.get("ingredients"):
            payload["ingredients"] = item["ingredients"]
        if item.get("benefits"):
            payload["benefits"] = item["benefits"]
        api("PATCH", f"/rest/v1/products?id=eq.{rows[0]['id']}", payload, prefer="return=minimal")
        print(f"Updated copy: {slug}")


def create_new(spec: dict) -> None:
    print("=== Creating high-confidence new products ===")
    products = spec.get("products") or []
    categories = api("GET", "/rest/v1/categories?select=id,name,slug")
    if not isinstance(categories, list):
        categories = []
    print(f"Loaded {len(categories)} categories")

    for item in products:
        slug = item["slug"]
        existing = api("GET", f"/rest/v1/products?select=id&slug=eq.{urllib.parse.quote(slug)}&limit=1")
        if existing:
            print(f"Already exists, skipping create: {slug}")
            continue

        category_id = match_category(categories, item.get("category_hints") or [])
        payload = {
            "name": item["name"],
            "slug": slug,
            "short_description": item.get("short_description") or "",
            "full_description": item.get("full_description") or "",
            "brand": "Nile Tropical",
            "is_active": True,
            "is_new": True,
            "is_featured": False,
            "is_bestseller": False,
            "is_promotional": False,
        }
        for field in ("ingredients", "benefits", "how_to_use", "warnings"):
            if item.get(field):
                payload[field] = item[field]
        if category_id:
            payload["category_id"] = category_id

        created = api("POST", "/rest/v1/products", payload)
        product_id = created[0]["id"] if isinstance(created, list) else created["id"]

        api(
            "POST",
            "/rest/v1/product_variants",
            {
                "product_id": product_id,
                "sku": item["sku"],
                "name": item.get("variant_name") or "Default",
                "price": item["price"],
                "stock_quantity": 0,
                "reorder_level": 5,
                "is_active": True,
            },
            prefer="return=minimal",
        )
        print(
            f"Created product: {slug} ({product_id}) "
            f"category={category_id or 'none'} price={item['price']} stock=0"
        )


def main() -> None:
    global SUPABASE_URL, SERVICE_KEY
    SUPABASE_URL = require_env("SUPABASE_URL")
    SERVICE_KEY = require_env("SUPABASE_SERVICE_ROLE_KEY")

    root = Path("assets/products")
    copy_path = root / "catalog-copy.json"
    new_path = root / "catalog-new.json"
    if not copy_path.exists():
        raise SystemExit(f"missing {copy_path}")

    patch_existing(json.loads(copy_path.read_text()))
    if new_path.exists():
        create_new(json.loads(new_path.read_text()))
    else:
        print("No catalog-new.json; skipping creates.")


if __name__ == "__main__":
    main()
