# B2B Price List Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a `/price-list` page that displays all product variants in a filterable table with add-to-cart functionality and Excel/PDF export.

**Architecture:** Single controller (`PriceListController`) with index action for viewing/filtering and export action for downloads. Uses existing `CartItemsController#create` for cart integration. Turbo Frames for instant filter updates without page reload.

**Tech Stack:** Rails 8, Turbo Frames, Stimulus, TailwindCSS/DaisyUI, Prawn (PDF), caxlsx (Excel)

---

## Task 1: Add caxlsx gem for Excel export

**Files:**
- Modify: `Gemfile`

**Step 1: Add the gem**

Add after the prawn gems (around line 45):

```ruby
# Excel generation for price list export
gem "caxlsx", "~> 4.1"
```

**Step 2: Install the gem**

Run: `bundle install`
Expected: caxlsx gem installed successfully

**Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "Add caxlsx gem for Excel export"
```

---

## Task 2: Create PriceListController with index action

**Files:**
- Create: `app/controllers/price_list_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Create the controller**

```ruby
# app/controllers/price_list_controller.rb
class PriceListController < ApplicationController
  allow_unauthenticated_access

  def index
    @variants = filtered_variants
    @categories = Category.where.not(slug: "branded-products").order(:position)
    @materials = available_materials
    @sizes = available_sizes
  end

  private

  def filtered_variants
    variants = ProductVariant.active
                             .joins(:product)
                             .includes(product: :category)
                             .where(products: { product_type: "standard", active: true })
                             .order("products.name ASC, product_variants.position ASC")

    variants = variants.where(products: { category_id: category_ids }) if params[:category].present?
    variants = filter_by_material(variants) if params[:material].present?
    variants = filter_by_size(variants) if params[:size].present?
    variants = search_variants(variants) if params[:q].present?

    variants
  end

  def category_ids
    Category.where(slug: params[:category]).pluck(:id)
  end

  def filter_by_material(variants)
    # Filter by material in option_values JSONB
    variants.where("product_variants.option_values->>'material' = ?", params[:material])
  end

  def filter_by_size(variants)
    # Filter by size in option_values JSONB
    variants.where("product_variants.option_values->>'size' = ?", params[:size])
  end

  def search_variants(variants)
    query = "%#{ProductVariant.sanitize_sql_like(params[:q])}%"
    variants.where(
      "products.name ILIKE ? OR product_variants.sku ILIKE ? OR product_variants.name ILIKE ?",
      query, query, query
    )
  end

  def available_materials
    ProductVariant.active
                  .joins(:product)
                  .where(products: { product_type: "standard", active: true })
                  .pluck(Arel.sql("DISTINCT product_variants.option_values->>'material'"))
                  .compact
                  .sort
  end

  def available_sizes
    ProductVariant.active
                  .joins(:product)
                  .where(products: { product_type: "standard", active: true })
                  .pluck(Arel.sql("DISTINCT product_variants.option_values->>'size'"))
                  .compact
                  .sort_by { |s| s.scan(/\d+/).first&.to_i || 999 }
  end
end
```

**Step 2: Add route**

In `config/routes.rb`, add after line 40 (after the `faqs` route):

```ruby
# Price list for B2B customers
get "price-list", to: "price_list#index"
```

**Step 3: Verify controller loads**

Run: `rails runner "PriceListController.new"`
Expected: No errors

**Step 4: Commit**

```bash
git add app/controllers/price_list_controller.rb config/routes.rb
git commit -m "Add PriceListController with filtering logic"
```

---

## Task 3: Create price list index view with filter bar

**Files:**
- Create: `app/views/price_list/index.html.erb`

**Step 1: Create the view**

```erb
<%# app/views/price_list/index.html.erb %>
<% content_for :title, "Price List | Afida" %>
<% content_for :meta_description, "Complete price list for Afida eco-friendly catering supplies. Filter by category, material, or size. Export to Excel or PDF." %>

<div class="drawer drawer-end" data-controller="cart-drawer">
  <input id="cart-drawer" type="checkbox" class="drawer-toggle" data-cart-drawer-target="checkbox" aria-label="Toggle shopping cart" />

  <div class="drawer-content">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="flex flex-col md:flex-row md:items-center md:justify-between mb-6">
        <div>
          <h1 class="text-3xl font-bold">Price List</h1>
          <p class="text-gray-600 mt-1">All prices exclude VAT. Free UK delivery on orders over £100.</p>
        </div>
        <div class="flex gap-2 mt-4 md:mt-0">
          <%= link_to price_list_path(request.query_parameters.merge(format: :xlsx)),
              class: "btn btn-outline btn-sm", data: { turbo: false } do %>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Excel
          <% end %>
          <%= link_to price_list_path(request.query_parameters.merge(format: :pdf)),
              class: "btn btn-outline btn-sm", data: { turbo: false } do %>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            PDF
          <% end %>
        </div>
      </div>

      <!-- Filter Bar -->
      <%= form_with url: price_list_path, method: :get, data: { controller: "form", turbo_frame: "price_list_table" } do %>
        <div class="flex flex-wrap gap-3 mb-6 items-end">
          <div class="form-control w-full md:w-48">
            <%= label_tag :category, "Category", class: "label label-text" %>
            <%= select_tag :category,
                options_for_select([["All Categories", ""]] + @categories.map { |c| [c.name, c.slug] }, params[:category]),
                class: "select select-bordered select-sm w-full",
                data: { action: "change->form#submit" } %>
          </div>

          <div class="form-control w-full md:w-40">
            <%= label_tag :material, "Material", class: "label label-text" %>
            <%= select_tag :material,
                options_for_select([["All Materials", ""]] + @materials.map { |m| [m, m] }, params[:material]),
                class: "select select-bordered select-sm w-full",
                data: { action: "change->form#submit" } %>
          </div>

          <div class="form-control w-full md:w-32">
            <%= label_tag :size, "Size", class: "label label-text" %>
            <%= select_tag :size,
                options_for_select([["All Sizes", ""]] + @sizes.map { |s| [s, s] }, params[:size]),
                class: "select select-bordered select-sm w-full",
                data: { action: "change->form#submit" } %>
          </div>

          <div class="form-control flex-1 min-w-[200px]">
            <%= label_tag :q, "Search", class: "label label-text" %>
            <%= text_field_tag :q, params[:q],
                placeholder: "Search products...",
                class: "input input-bordered input-sm w-full",
                data: { controller: "search", action: "input->search#debounce" } %>
          </div>

          <% if params[:category].present? || params[:material].present? || params[:size].present? || params[:q].present? %>
            <%= link_to "Clear", price_list_path, class: "btn btn-ghost btn-sm" %>
          <% end %>
        </div>
      <% end %>

      <!-- Table -->
      <%= turbo_frame_tag "price_list_table" do %>
        <%= render "table", variants: @variants %>
      <% end %>
    </div>
  </div>

  <!-- Cart Drawer -->
  <div class="drawer-side z-50">
    <label for="cart-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
    <div class="bg-base-200 w-80 min-h-full p-4">
      <%= render "shared/drawer_cart_content" %>
    </div>
  </div>
</div>
```

**Step 2: Verify view renders**

Run: `rails server` and visit `http://localhost:3000/price-list`
Expected: Page loads (will error on missing `_table` partial - that's Task 4)

**Step 3: Commit**

```bash
git add app/views/price_list/index.html.erb
git commit -m "Add price list index view with filter bar"
```

---

## Task 4: Create price list table partial with add-to-cart

**Files:**
- Create: `app/views/price_list/_table.html.erb`
- Create: `app/views/price_list/_row.html.erb`

**Step 1: Create the table partial**

```erb
<%# app/views/price_list/_table.html.erb %>
<div class="overflow-x-auto">
  <table class="table table-zebra w-full">
    <thead>
      <tr class="bg-base-200">
        <th class="text-left">Product</th>
        <th class="text-left hidden md:table-cell">SKU</th>
        <th class="text-left">Size</th>
        <th class="text-left hidden lg:table-cell">Material</th>
        <th class="text-right hidden md:table-cell">Pack Size</th>
        <th class="text-right">Price/Pack</th>
        <th class="text-right hidden lg:table-cell">Price/Unit</th>
        <th class="text-center">Qty</th>
        <th class="text-center"></th>
      </tr>
    </thead>
    <tbody>
      <% variants.each do |variant| %>
        <%= render "row", variant: variant %>
      <% end %>
    </tbody>
  </table>
</div>

<% if variants.empty? %>
  <div class="text-center py-12">
    <p class="text-gray-500">No products found matching your filters.</p>
    <%= link_to "Clear filters", price_list_path, class: "btn btn-outline btn-sm mt-4" %>
  </div>
<% else %>
  <p class="text-sm text-gray-500 mt-4"><%= pluralize(variants.count, "product") %> shown</p>
<% end %>
```

**Step 2: Create the row partial**

```erb
<%# app/views/price_list/_row.html.erb %>
<tr class="hover" id="<%= dom_id(variant) %>">
  <td>
    <%= link_to product_path(variant.product), class: "link link-hover font-medium" do %>
      <%= variant.product.name %>
    <% end %>
  </td>
  <td class="hidden md:table-cell text-gray-500 font-mono text-sm"><%= variant.sku %></td>
  <td><%= variant.option_values["size"] || variant.name %></td>
  <td class="hidden lg:table-cell"><%= variant.option_values["material"] || "-" %></td>
  <td class="text-right hidden md:table-cell"><%= number_with_delimiter(variant.pac_size || 1) %></td>
  <td class="text-right font-medium"><%= number_to_currency(variant.price) %></td>
  <td class="text-right hidden lg:table-cell text-gray-500">
    <%= number_to_currency(variant.unit_price, precision: 4) %>
  </td>
  <td class="text-center">
    <%= form_with url: cart_cart_items_path,
        data: { turbo_frame: "_top", controller: "price-list-row" } do |f| %>
      <%= f.hidden_field :cart_item, value: nil, name: "cart_item[variant_sku]", id: nil %>
      <%= f.hidden_field :cart_item, value: variant.sku, name: "cart_item[variant_sku]" %>
      <%= f.select :quantity,
          options_for_select([[1, 1], [2, 2], [3, 3], [5, 5], [10, 10]], 1),
          {},
          { name: "cart_item[quantity]", class: "select select-bordered select-xs w-16" } %>
      <button type="submit" class="btn btn-primary btn-xs ml-1">
        Add
      </button>
    <% end %>
  </td>
  <td></td>
</tr>
```

**Step 3: Verify table renders**

Visit: `http://localhost:3000/price-list`
Expected: Table with all products, filters work, Add buttons visible

**Step 4: Commit**

```bash
git add app/views/price_list/_table.html.erb app/views/price_list/_row.html.erb
git commit -m "Add price list table and row partials"
```

---

## Task 5: Add Excel export action

**Files:**
- Modify: `app/controllers/price_list_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Add export action to controller**

Add after the `index` action:

```ruby
def export
  @variants = filtered_variants

  respond_to do |format|
    format.xlsx do
      response.headers["Content-Disposition"] = "attachment; filename=\"#{export_filename}.xlsx\""
      render xlsx: "export", layout: false
    end
    format.pdf do
      pdf = PriceListPdf.new(@variants, filter_description)
      send_data pdf.render,
                filename: "#{export_filename}.pdf",
                type: "application/pdf",
                disposition: "attachment"
    end
  end
end
```

Add to private section:

```ruby
def export_filename
  parts = ["afida-price-list"]
  parts << params[:category] if params[:category].present?
  parts << Date.current.to_s
  parts.join("-")
end

def filter_description
  parts = []
  parts << Category.find_by(slug: params[:category])&.name if params[:category].present?
  parts << params[:material] if params[:material].present?
  parts << params[:size] if params[:size].present?
  parts << "\"#{params[:q]}\"" if params[:q].present?
  parts.any? ? "Filtered by: #{parts.join(', ')}" : "All products"
end
```

**Step 2: Update routes**

Replace the price-list route with:

```ruby
# Price list for B2B customers
get "price-list", to: "price_list#index", as: :price_list
get "price-list/export", to: "price_list#export", as: :price_list_export, defaults: { format: :xlsx }
```

**Step 3: Update view export links**

In `app/views/price_list/index.html.erb`, update the export links (around lines 17-28):

```erb
<%= link_to price_list_export_path(request.query_parameters.merge(format: :xlsx)),
    class: "btn btn-outline btn-sm", data: { turbo: false } do %>
```

And for PDF:
```erb
<%= link_to price_list_export_path(request.query_parameters.merge(format: :pdf)),
    class: "btn btn-outline btn-sm", data: { turbo: false } do %>
```

**Step 4: Commit**

```bash
git add app/controllers/price_list_controller.rb config/routes.rb app/views/price_list/index.html.erb
git commit -m "Add export action with xlsx and pdf format support"
```

---

## Task 6: Create Excel export template

**Files:**
- Create: `app/views/price_list/export.xlsx.axlsx`

**Step 1: Create the Excel template**

```ruby
# app/views/price_list/export.xlsx.axlsx
wb = xlsx_package.workbook

wb.add_worksheet(name: "Price List") do |sheet|
  # Header style
  header_style = sheet.styles.add_style(
    b: true,
    bg_color: "4A5568",
    fg_color: "FFFFFF",
    alignment: { horizontal: :center }
  )

  currency_style = sheet.styles.add_style(num_fmt: 7)
  unit_price_style = sheet.styles.add_style(num_fmt: 4)

  # Header row
  sheet.add_row [
    "Product",
    "SKU",
    "Size",
    "Material",
    "Pack Size",
    "Price/Pack",
    "Price/Unit"
  ], style: header_style

  # Data rows
  @variants.each do |variant|
    sheet.add_row [
      variant.product.name,
      variant.sku,
      variant.option_values["size"] || variant.name,
      variant.option_values["material"] || "",
      variant.pac_size || 1,
      variant.price.to_f,
      variant.unit_price.to_f
    ], style: [nil, nil, nil, nil, nil, currency_style, unit_price_style]
  end

  # Auto-width columns
  sheet.column_widths 40, 15, 15, 15, 12, 12, 12
end
```

**Step 2: Verify Excel export works**

Visit: `http://localhost:3000/price-list` and click "Excel" button
Expected: Downloads .xlsx file that opens in Excel

**Step 3: Commit**

```bash
git add app/views/price_list/export.xlsx.axlsx
git commit -m "Add Excel export template"
```

---

## Task 7: Create PDF export service

**Files:**
- Create: `app/services/price_list_pdf.rb`

**Step 1: Create the PDF service**

```ruby
# app/services/price_list_pdf.rb
class PriceListPdf < Prawn::Document
  include ActionView::Helpers::NumberHelper

  def initialize(variants, filter_description)
    super(page_size: "A4", page_layout: :landscape, margin: 30)
    @variants = variants
    @filter_description = filter_description

    generate
  end

  private

  def generate
    header
    price_table
    footer
  end

  def header
    text "Afida Price List", size: 24, style: :bold
    move_down 5
    text @filter_description, size: 10, color: "666666"
    text "Generated: #{Date.current.strftime('%d %B %Y')}", size: 10, color: "666666"
    text "All prices exclude VAT", size: 10, color: "666666"
    move_down 15
  end

  def price_table
    table_data = [
      ["Product", "SKU", "Size", "Material", "Pack Size", "Price/Pack", "Price/Unit"]
    ]

    @variants.each do |variant|
      table_data << [
        variant.product.name,
        variant.sku,
        variant.option_values["size"] || variant.name,
        variant.option_values["material"] || "-",
        number_with_delimiter(variant.pac_size || 1),
        number_to_currency(variant.price),
        number_to_currency(variant.unit_price, precision: 4)
      ]
    end

    table(table_data, header: true, width: bounds.width) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = "4A5568"
      t.row(0).text_color = "FFFFFF"
      t.cells.padding = [5, 8]
      t.cells.borders = [:bottom]
      t.cells.border_color = "DDDDDD"
      t.column(0).width = 180
      t.column(1).width = 80
      t.column(2).width = 70
      t.column(3).width = 80
      t.column(4).width = 60
      t.column(4).align = :right
      t.column(5).width = 70
      t.column(5).align = :right
      t.column(6).width = 70
      t.column(6).align = :right
    end
  end

  def footer
    number_pages "Page <page> of <total>", at: [bounds.right - 100, 0], size: 9
  end
end
```

**Step 2: Verify PDF export works**

Visit: `http://localhost:3000/price-list` and click "PDF" button
Expected: Downloads .pdf file that opens correctly

**Step 3: Commit**

```bash
git add app/services/price_list_pdf.rb
git commit -m "Add PDF export service using Prawn"
```

---

## Task 8: Add "Price List" to main navigation

**Files:**
- Modify: `app/views/shared/_navbar.html.erb`

**Step 1: Add Price List link to desktop nav**

In the `navbar-center` ul (around line 27), add after "Branding":

```erb
<li class="text-lg font-medium"><%= link_to "Price List", price_list_path, class: "hover:underline hover:decoration-secondary hover:decoration-2 hover:underline-offset-8 transition-colors #{current_page?(price_list_path) ? 'underline decoration-secondary decoration-2 underline-offset-8' : ''}" %></li>
```

**Step 2: Add Price List link to mobile nav**

In the mobile dropdown ul (around line 17, after "Branding"):

```erb
<li class="text-lg font-medium"><%= link_to "Price List", price_list_path, class: "block hover:underline hover:decoration-secondary hover:decoration-2 hover:underline-offset-8 transition-colors #{current_page?(price_list_path) ? 'underline decoration-secondary decoration-2 underline-offset-8' : ''}" %></li>
```

**Step 3: Verify navigation**

Visit: `http://localhost:3000`
Expected: "Price List" appears in both desktop and mobile navigation

**Step 4: Commit**

```bash
git add app/views/shared/_navbar.html.erb
git commit -m "Add Price List link to main navigation"
```

---

## Task 9: Register form and search Stimulus controllers (if needed)

**Files:**
- Check: `app/frontend/entrypoints/application.js`

**Step 1: Verify controllers are registered**

Check if `form` and `search` controllers are in the `lazyControllers` object. If not present, add them:

```javascript
"form": () => import("../javascript/controllers/form_controller"),
"search": () => import("../javascript/controllers/search_controller"),
```

**Step 2: Verify the form controller exists**

Read `app/frontend/javascript/controllers/form_controller.js`. If it doesn't exist, create:

```javascript
// app/frontend/javascript/controllers/form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
```

**Step 3: Verify the search controller exists**

Read `app/frontend/javascript/controllers/search_controller.js`. If it doesn't exist, create:

```javascript
// app/frontend/javascript/controllers/search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  debounce() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.form.requestSubmit()
    }, 300)
  }
}
```

**Step 4: Commit if changes made**

```bash
git add app/frontend/javascript/controllers/ app/frontend/entrypoints/application.js
git commit -m "Ensure form and search Stimulus controllers exist"
```

---

## Task 10: Manual testing checklist

**Test the complete feature:**

1. **Page loads:** Visit `/price-list` — table displays all standard products
2. **Category filter:** Select "Napkins" — only napkins shown
3. **Material filter:** Select "Paper" — only paper products shown
4. **Size filter:** Select "12oz" — only 12oz products shown
5. **Combined filters:** Select category AND material — intersection shown
6. **Search:** Type "cup" — products matching "cup" shown
7. **Clear filters:** Click "Clear" — all products shown again
8. **Add to cart:** Select qty 2, click Add — cart drawer opens with item
9. **Increment existing:** Add same product again — quantity increases (doesn't duplicate)
10. **Excel export:** Click Excel — downloads file, opens correctly
11. **PDF export:** Click PDF — downloads file, opens correctly
12. **Filtered export:** Apply filters, then export — only filtered items in file
13. **Mobile view:** Resize to mobile — columns hide appropriately, still usable
14. **Navigation:** Click "Price List" in navbar — navigates to page

**Step 1: Run through checklist**

Test each item above manually.

**Step 2: Commit final polish if needed**

```bash
git add -A
git commit -m "Polish price list feature based on manual testing"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add caxlsx gem | Gemfile |
| 2 | Create controller with filtering | Controller, routes |
| 3 | Create index view with filter bar | View |
| 4 | Create table and row partials | Partials |
| 5 | Add export action | Controller, routes |
| 6 | Create Excel template | axlsx template |
| 7 | Create PDF service | Service class |
| 8 | Add to navigation | Navbar partial |
| 9 | Ensure Stimulus controllers | JS controllers |
| 10 | Manual testing | N/A |

**Total estimated new files:** 6
**Total modified files:** 4
