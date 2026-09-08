import { Turbo } from "@hotwired/turbo-rails"

const TOOLS = [
  {
    name: "search_catalog",
    description: "Search Afida products by name, SKU, or category.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search text" },
        category: { type: "string", description: "Optional category slug" }
      },
      required: ["query"]
    },
    execute: async ({ query, category }) => {
      const params = new URLSearchParams()
      if (query) params.set("q", query)
      if (category) params.set("category", category)
      const response = await fetch(`/api/v1/products?${params}`)
      if (!response.ok) throw new Error("Catalog search failed")
      return await response.json()
    }
  },
  {
    name: "get_product",
    description: "Fetch one Afida product by slug.",
    inputSchema: {
      type: "object",
      properties: {
        slug: { type: "string", description: "Product URL slug" }
      },
      required: ["slug"]
    },
    execute: async ({ slug }) => {
      const response = await fetch(`/api/v1/products/${encodeURIComponent(slug)}`)
      if (!response.ok) throw new Error("Product not found")
      return await response.json()
    }
  },
  {
    name: "list_categories",
    description: "List Afida catalog categories.",
    inputSchema: { type: "object", properties: {} },
    execute: async () => {
      const response = await fetch("/api/v1/categories")
      if (!response.ok) throw new Error("Category list failed")
      return await response.json()
    }
  },
  {
    name: "add_to_cart",
    description: "Add a standard catalog product to the current browser cart by SKU.",
    inputSchema: {
      type: "object",
      properties: {
        sku: { type: "string", description: "Product SKU" },
        quantity: { type: "integer", description: "Number of packs", default: 1 }
      },
      required: ["sku"]
    },
    execute: async ({ sku, quantity }) => {
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      const body = new FormData()
      body.append("cart_item[sku]", sku)
      body.append("cart_item[quantity]", String(quantity || 1))
      const response = await fetch("/cart/cart_items", {
        method: "POST",
        headers: { "X-CSRF-Token": csrf, Accept: "text/vnd.turbo-stream.html" },
        body
      })
      if (!response.ok) throw new Error("Could not add to cart")
      Turbo.renderStreamMessage(await response.text())
      return { ok: true, sku, quantity: quantity || 1 }
    }
  }
]

let registered = false

function registerWebMcp() {
  const context = navigator.modelContext
  if (!context || registered) return
  registered = true

  TOOLS.forEach((tool) => {
    if (typeof context.registerTool === "function") context.registerTool(tool)
  })

  if (typeof context.provideContext === "function") {
    context.provideContext({ tools: TOOLS })
  }
}

document.addEventListener("DOMContentLoaded", registerWebMcp)
document.addEventListener("turbo:load", registerWebMcp)
