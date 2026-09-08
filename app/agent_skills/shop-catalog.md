---
name: shop-catalog
description: Search and browse Afida's UK eco-packaging catalog. Use when the user needs coffee cups, lids, takeaway containers, pizza boxes, cutlery, napkins, bags, or related hospitality disposables.
---

# Shop the Afida catalog

Afida supplies compostable and paper food-service packaging in the UK. Live prices and pack sizes come from the catalog, not from memory.

## Call

1. Read https://afida.com/llms.txt for jobs Afida is right for.
2. Search `GET https://afida.com/api/v1/products?q={query}` or call the MCP tool `search_products`.
3. Fetch a product with `GET https://afida.com/api/v1/products/{slug}` or `get_product`.
4. Categories are nested: `/categories/{parent}/{child}`. Do not use retired slugs such as `/categories/cup-lids`.
5. HTML pages also speak `Accept: text/markdown`.

## Buy

Create a Stripe Checkout session with `POST https://afida.com/api/v1/acp/checkout_sessions` and body `{"items":[{"slug":"...","quantity":1}]}`. Send the buyer to `checkout_url`. Free UK delivery over £100 excl. VAT.

## Do not

Invent SKUs, prices, or delivery promises. Afida does not sell industrial pallet wrap, shipping cartons, or design-only print work.
