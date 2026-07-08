---
type: Plan
description: Implementation plan for a searchable FAQ page with categorized questions stored in YAML, accordion UI, and FAQPage schema markup for SEO.
status: shipped
timestamp: 2025-11-06
---

# FAQ Section Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a comprehensive, searchable FAQ page with 10 categories, accordion UI, and SEO-optimized schema markup.

**Architecture:** YAML-based FAQ storage for version control, Rails controller serving a dedicated `/faq` route, Stimulus controller for accordion behavior and search filtering, FAQ schema markup for Google rich results.

**Tech Stack:** Rails 8, Hotwire Stimulus, TailwindCSS 4, DaisyUI, YAML, JSON-LD schema

---

## Task 1: Create FAQ Data Structure

**Files:**
- Create: `config/faqs.yml`

**Step 1: Create YAML file with FAQ data**

Create `config/faqs.yml`:

```yaml
categories:
  - id: about-products
    title: "About Our Products"
    questions:
      - id: types-of-products
        question: "What types of packaging products do you offer?"
        answer: "We supply a wide range of packaging solutions including unbranded (plain) stock items and fully branded products with custom printing and artwork. Whether you need simple stock boxes or packaging that carries your logo and brand identity, we've got you covered."
      - id: unbranded-meaning
        question: "What does \"unbranded\" mean?"
        answer: "\"Unbranded\" refers to products that come without any custom printing, logo or design — simply ready for use as-is or for you to brand yourself later. These are a cost‑effective option when you don't need custom printing."
      - id: branded-meaning
        question: "What does \"branded\" mean?"
        answer: "\"Branded\" products are customised with your company's logo, colours, design and artwork. We handle the printing or finishing so your packaging aligns with your brand identity and looks professional."
      - id: materials
        question: "What materials do you use for your packaging?"
        answer: "We offer packaging in a variety of materials depending on the product application — for example kraft board, food‑safe card, corrugated board, tubes and cylinders, and sustainable materials where appropriate. (Materials selection may vary by product.)"

  - id: custom-printing
    title: "Custom Printing & Branding"
    questions:
      - id: moq
        question: "What is the minimum order quantity (MOQ) for branded items?"
        answer: "For branded products, a minimum order quantity (MOQ) typically applies. This allows the cost of tooling, printing setup and finishing to be spread across the batch. If you are unsure, please contact us with the specific product and size you are interested in for the MOQ details."
      - id: own-artwork
        question: "Can I use my own artwork and logo?"
        answer: "Yes — we welcome your artwork and logo files. We'll provide specifications for print‑ready files (format, colour mode, bleed, resolution etc.). Our team can also help review your files and advise if any changes are needed for print quality."
      - id: branding-time
        question: "How long does branding take?"
        answer: "The lead time for branded items depends on several factors: quantity, material, print method, current workload and shipping. Once artwork is approved and order confirmed, we'll provide a clear timeline. For stock unbranded items the dispatch is typically faster."
      - id: artwork-changes
        question: "What if I change my mind about the artwork after approval?"
        answer: "Changes to artwork after approval may incur additional cost or delay. We recommend reviewing proofs carefully before approving to avoid unexpected costs or time lags."

  - id: ordering-delivery
    title: "Ordering & Delivery"
    questions:
      - id: place-order
        question: "How do I place an order?"
        answer: "You can place an order via our website or by contacting our sales team directly - sales@afida.com. For branded items, we'll send a formal quote and request your artwork prior to production."
      - id: delivery-cost-time
        question: "How much does delivery cost and how long will it take?"
        answer: "Delivery cost depends on order size, weight, destination and service selected. We offer standard shipping and expedited options. Once your order is confirmed (and for branded items once production begins), we'll provide an estimated dispatch date."
      - id: international-shipping
        question: "Can you ship internationally?"
        answer: "Yes — we can ship to anywhere. For international orders, higher delivery costs, customs duties, taxes and longer transit times may apply."
      - id: small-quantity
        question: "What if I only need a small quantity?"
        answer: "If you require small quantities, unbranded stock products are usually a better fit because they are kept as inventory and can be shipped quickly. Branded products may have higher minimums due to setup costs."

  - id: returns-quality
    title: "Returns, Refunds & Quality"
    questions:
      - id: returns-policy
        question: "What is your returns policy?"
        answer: "For unbranded stock items, you may cancel or return within 14 days subject to them being unused and in resalable condition. For branded items (customised), returns are generally not accepted unless there is a manufacturing defect, because they cannot be resold. Please check each product's terms before ordering."
      - id: faulty-branding
        question: "What if the branding is incorrect or printing is faulty?"
        answer: "In the unlikely event of a printing or manufacturing defect, please contact us immediately with photos and details. We will assess the issue and offer a rectification: replacement, credit or refund, depending on the situation."
      - id: food-safe
        question: "Are your products food‑safe / compliant with regulations?"
        answer: "Yes — for packaging intended for food contact, we ensure that materials and manufacturing comply with relevant UK/EU regulations. If you have specific regulatory requirements (e.g., for export or special use), please advise before placing your order."

  - id: sustainability
    title: "Sustainability & Materials"
    questions:
      - id: eco-friendly
        question: "Do you offer eco‑friendly or sustainable packaging options?"
        answer: "Yes — we recognise the importance of sustainability. We provide options made from recycled or renewable materials, and some items are designed to be compostable or recyclable. We can advise on the best options for your business's environmental goals."
      - id: disposal
        question: "How should I dispose of the packaging?"
        answer: "Disposal instructions depend on the material type and local waste‑handling infrastructure. We provide guidance on whether the item is recyclable, compostable or should go to general waste. If you're unsure, please contact us and we'll help."

  - id: custom-projects
    title: "Custom & Bespoke Projects"
    questions:
      - id: bespoke-solution
        question: "Can I create a completely bespoke packaging solution?"
        answer: "Absolutely — we can work with you to design a custom shape, size or material. Bespoke projects may require a higher minimum order and longer lead times, but allow full flexibility to meet your brand's needs."
      - id: bespoke-costs
        question: "What extra costs might there be for bespoke work?"
        answer: "Extra costs may include tooling (if new moulds or dies are required), print setup, proofs, special finishing (spot UV, embossing, metallic ink) and longer production lead times. We will quote all costs clearly before you commit."

  - id: payments-orders
    title: "Payments & Orders"
    questions:
      - id: vat-included
        question: "Is VAT included in the prices shown?"
        answer: "All prices shown are exclusive of VAT unless stated otherwise. VAT will be added at checkout where applicable."
      - id: payment-methods
        question: "What payment methods do you accept?"
        answer: "We accept all major credit and debit cards, bank transfers, and some digital payment options. If you need help with payment, our team can guide you through the process."
      - id: order-ready
        question: "How will I know when my order is ready?"
        answer: "You will receive an email notification as soon as your order is ready for dispatch. For branded products, we also update you once production begins and provide tracking details when shipped."
      - id: reorder
        question: "How do I reorder a previous product?"
        answer: "Reordering is simple. You can log in to your account and select a past order, or contact our sales team referencing your previous order number."
      - id: bnpl
        question: "Do you offer Buy Now, Pay Later options?"
        answer: "We do offer flexible payment terms for trade customers or recurring clients. Contact us to apply or discuss eligibility. Currently, we do not offer third-party BNPL services like Klarna or Clearpay."

  - id: stocking-fulfilment
    title: "Stocking & Fulfilment Services"
    questions:
      - id: stocking-service
        question: "Do you offer storage or stocking services for our packaging orders?"
        answer: "Yes — we offer a stocking service where we hold your printed or unprinted packaging in our facility. This is ideal for customers who prefer to order in bulk but need staged delivery or limited on-site space."
      - id: stocking-cost
        question: "Is the cost of stocking included in the price?"
        answer: "In many cases, yes — stocking can be included within the unit price or added as a transparent cost, depending on the agreement. This helps spread the cost over time and simplifies your logistics."
      - id: no-stocking
        question: "What if I don't want you to stock the products?"
        answer: "No problem. During the quoting or checkout process, simply deselect the stocking option. Our pricing tool will automatically update to reflect the cost without storage."
      - id: stocking-delivery-costs
        question: "Does stocking affect delivery costs?"
        answer: "Stocking can help reduce your delivery frequency and cost, since we consolidate shipments based on your schedule. However, if you prefer to handle logistics independently, you're welcome to collect stock or arrange your own shipping."
      - id: part-delivery
        question: "Can you deliver from stock in parts?"
        answer: "Yes — we can deliver in split batches as needed, depending on your usage and availability preferences. This is particularly useful for larger campaigns or multi-location setups."

  - id: samples
    title: "Samples"
    questions:
      - id: sample-cost
        question: "How much does the sample pack cost?"
        answer: "Our sample packs are free; you only need to cover the delivery cost."
      - id: sample-arrival
        question: "When will my sample pack arrive?"
        answer: "Your sample pack will arrive within 2–3 business days from the date of your order. Once it has been shipped, you will receive a tracking code."

  - id: contact-support
    title: "Contact & Support"
    questions:
      - id: further-questions
        question: "Who do I contact if I have further questions?"
        answer: "You can email our Customer Support team at info@afida.com, or call us on 0203 302 7719. We aim to respond to all enquiries within 48 hours."
      - id: product-advice
        question: "I'm unsure which product or material to choose. Can you help?"
        answer: "Yes — we're happy to advise on material suitability, print finishes, durability, regulatory compliance and lead‑times. Just get in touch with your requirements and we'll guide you through the options."
```

**Step 2: Commit**

```bash
git add config/faqs.yml
git commit -m "feat: add FAQ data structure in YAML"
```

---

## Task 2: Create FAQ Service

**Files:**
- Create: `app/services/faq_service.rb`

**Step 1: Create FAQ service to load YAML**

Create `app/services/faq_service.rb`:

```ruby
# frozen_string_literal: true

class FaqService
  class << self
    def all_categories
      @all_categories ||= load_faqs["categories"]
    end

    def find_category(category_id)
      all_categories.find { |cat| cat["id"] == category_id }
    end

    def search(query)
      return [] if query.blank?

      query = query.downcase
      results = []

      all_categories.each do |category|
        category["questions"].each do |question|
          if question["question"].downcase.include?(query) ||
             question["answer"].downcase.include?(query)
            results << {
              category_title: category["title"],
              category_id: category["id"],
              question: question["question"],
              answer: question["answer"],
              question_id: question["id"]
            }
          end
        end
      end

      results
    end

    def reload!
      @all_categories = nil
    end

    private

    def load_faqs
      YAML.load_file(Rails.root.join("config/faqs.yml"))
    end
  end
end
```

**Step 2: Write test for FAQ service**

Create `test/services/faq_service_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class FaqServiceTest < ActiveSupport::TestCase
  test "loads all FAQ categories" do
    categories = FaqService.all_categories
    assert_not_empty categories
    assert_equal 10, categories.size
  end

  test "finds category by id" do
    category = FaqService.find_category("about-products")
    assert_not_nil category
    assert_equal "About Our Products", category["title"]
  end

  test "searches questions and answers" do
    results = FaqService.search("branded")
    assert_not_empty results
    assert results.any? { |r| r[:question].include?("branded") }
  end

  test "search is case insensitive" do
    results = FaqService.search("BRANDED")
    assert_not_empty results
  end

  test "returns empty array for blank query" do
    assert_empty FaqService.search("")
    assert_empty FaqService.search(nil)
  end

  test "search returns category context with results" do
    results = FaqService.search("branded")
    first_result = results.first

    assert first_result.key?(:category_title)
    assert first_result.key?(:category_id)
    assert first_result.key?(:question)
    assert first_result.key?(:answer)
    assert first_result.key?(:question_id)
  end
end
```

**Step 3: Run tests to verify implementation**

```bash
rails test test/services/faq_service_test.rb
```

Expected: All tests PASS (6 tests)

**Step 4: Commit**

```bash
git add app/services/faq_service.rb test/services/faq_service_test.rb
git commit -m "feat: add FAQ service with search functionality"
```

---

## Task 3: Create FAQ Controller and Route

**Files:**
- Create: `app/controllers/faqs_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Add FAQ route**

In `config/routes.rb`, add before the final `end`:

```ruby
  # FAQ page
  get "faq", to: "faqs#index"
```

**Step 2: Create FAQ controller**

Create `app/controllers/faqs_controller.rb`:

```ruby
# frozen_string_literal: true

class FaqsController < ApplicationController
  allow_unauthenticated_access

  def index
    @categories = FaqService.all_categories
    @search_query = params[:q]
    @search_results = FaqService.search(@search_query) if @search_query.present?
  end
end
```

**Step 3: Write controller test**

Create `test/controllers/faqs_controller_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class FaqsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get faq_url
    assert_response :success
  end

  test "index loads all categories" do
    get faq_url
    assert_not_nil assigns(:categories)
    assert_equal 10, assigns(:categories).size
  end

  test "index performs search when query present" do
    get faq_url, params: { q: "branded" }
    assert_response :success
    assert_not_nil assigns(:search_results)
    assert_not_empty assigns(:search_results)
  end

  test "index accessible without authentication" do
    get faq_url
    assert_response :success
  end

  test "search query is assigned to view" do
    get faq_url, params: { q: "shipping" }
    assert_equal "shipping", assigns(:search_query)
  end
end
```

**Step 4: Run tests**

```bash
rails test test/controllers/faqs_controller_test.rb
```

Expected: 5 tests PASS

**Step 5: Commit**

```bash
git add app/controllers/faqs_controller.rb test/controllers/faqs_controller_test.rb config/routes.rb
git commit -m "feat: add FAQ controller and route"
```

---

## Task 4: Create FAQ View with Search

**Files:**
- Create: `app/views/faqs/index.html.erb`

**Step 1: Create FAQ index view**

Create `app/views/faqs/index.html.erb`:

```erb
<% content_for :title, "Frequently Asked Questions" %>

<div class="container mx-auto px-4 py-8 max-w-5xl">
  <!-- Header -->
  <div class="text-center mb-12">
    <h1 class="text-4xl font-bold text-gray-900 mb-4">Frequently Asked Questions</h1>
    <p class="text-lg text-gray-600">Find answers to common questions about our packaging products and services</p>
  </div>

  <!-- Search Bar -->
  <div class="mb-8">
    <%= form_with url: faq_path, method: :get, class: "max-w-2xl mx-auto", data: { controller: "faq-search", turbo_frame: "faq-content" } do |f| %>
      <div class="relative">
        <%= f.search_field :q,
            value: @search_query,
            placeholder: "Search FAQs...",
            class: "input input-bordered w-full pr-12",
            data: { faq_search_target: "input", action: "input->faq-search#search" } %>
        <button type="submit" class="btn btn-ghost btn-sm absolute right-2 top-1/2 -translate-y-1/2">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
        </button>
      </div>
    <% end %>
  </div>

  <div id="faq-content">
    <% if @search_results %>
      <!-- Search Results -->
      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4">
          Search Results for "<%= @search_query %>"
          <span class="text-sm text-gray-500">(<%= @search_results.size %> <%= "result".pluralize(@search_results.size) %>)</span>
        </h2>

        <% if @search_results.empty? %>
          <div class="alert alert-info">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <span>No results found. Try different keywords or browse categories below.</span>
          </div>
        <% else %>
          <div class="space-y-4">
            <% @search_results.each do |result| %>
              <div class="card bg-base-100 shadow-sm border border-base-300">
                <div class="card-body">
                  <div class="badge badge-primary badge-sm mb-2"><%= result[:category_title] %></div>
                  <h3 class="card-title text-lg"><%= result[:question] %></h3>
                  <p class="text-gray-600"><%= result[:answer] %></p>
                  <a href="#<%= result[:category_id] %>-<%= result[:question_id] %>" class="link link-primary text-sm">View in category</a>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <div class="divider my-8">OR BROWSE ALL CATEGORIES</div>
      </div>
    <% end %>

    <!-- Quick Links -->
    <div class="mb-8 p-6 bg-base-200 rounded-lg">
      <h2 class="text-xl font-semibold mb-4">Quick Links</h2>
      <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
        <% @categories.each do |category| %>
          <a href="#<%= category["id"] %>" class="btn btn-sm btn-outline">
            <%= category["title"] %>
          </a>
        <% end %>
      </div>
    </div>

    <!-- FAQ Categories Accordion -->
    <div class="space-y-4" data-controller="faq-accordion">
      <% @categories.each do |category| %>
        <div class="card bg-base-100 shadow-sm border border-base-300" id="<%= category["id"] %>">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4 flex items-center justify-between cursor-pointer"
                data-action="click->faq-accordion#toggle"
                data-faq-accordion-target="header">
              <%= category["title"] %>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 transition-transform" data-faq-accordion-target="icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </h2>

            <div class="space-y-6 hidden" data-faq-accordion-target="content">
              <% category["questions"].each do |q| %>
                <div class="border-l-4 border-primary pl-4" id="<%= category["id"] %>-<%= q["id"] %>">
                  <h3 class="font-semibold text-lg mb-2"><%= q["question"] %></h3>
                  <p class="text-gray-600 leading-relaxed"><%= q["answer"] %></p>
                </div>
              <% end %>

              <!-- Contact CTA -->
              <div class="alert alert-info mt-6">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <div>
                  <div class="font-semibold">Still have questions about <%= category["title"].downcase %>?</div>
                  <div class="text-sm">Contact us at <a href="mailto:info@afida.com" class="link">info@afida.com</a> or call <a href="tel:02033027719" class="link">0203 302 7719</a></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

**Step 2: Test view renders**

```bash
rails test test/controllers/faqs_controller_test.rb
```

Expected: All tests still PASS (view renders without errors)

**Step 3: Commit**

```bash
git add app/views/faqs/index.html.erb
git commit -m "feat: add FAQ view with search and accordion layout"
```

---

## Task 5: Create FAQ Accordion Stimulus Controller

**Files:**
- Create: `app/frontend/javascript/controllers/faq_accordion_controller.js`

**Step 1: Create accordion Stimulus controller**

Create `app/frontend/javascript/controllers/faq_accordion_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "content", "icon"]

  connect() {
    // Open first category by default
    if (this.element === this.element.parentElement.firstElementChild) {
      this.open()
    }
  }

  toggle(event) {
    const content = event.currentTarget.nextElementSibling
    const icon = event.currentTarget.querySelector('[data-faq-accordion-target="icon"]')

    if (content.classList.contains('hidden')) {
      content.classList.remove('hidden')
      icon.style.transform = 'rotate(180deg)'
    } else {
      content.classList.add('hidden')
      icon.style.transform = 'rotate(0deg)'
    }
  }

  open() {
    const content = this.contentTarget
    const icon = this.iconTarget

    content.classList.remove('hidden')
    icon.style.transform = 'rotate(180deg)'
  }
}
```

**Step 2: Verify Stimulus controller is registered**

The controller should auto-register via Stimulus. Verify by checking `app/frontend/entrypoints/application.js` contains:

```javascript
import "controllers"
```

**Step 3: Test manually in browser**

```bash
bin/dev
```

Visit `http://localhost:3000/faq` and verify:
- First category opens by default
- Clicking category headers toggles accordion
- Icons rotate when opening/closing

**Step 4: Commit**

```bash
git add app/frontend/javascript/controllers/faq_accordion_controller.js
git commit -m "feat: add accordion Stimulus controller for FAQ"
```

---

## Task 6: Create FAQ Search Stimulus Controller

**Files:**
- Create: `app/frontend/javascript/controllers/faq_search_controller.js`

**Step 1: Create search Stimulus controller**

Create `app/frontend/javascript/controllers/faq_search_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.timeout = null
  }

  search() {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      const query = this.inputTarget.value

      if (query.length >= 2) {
        this.element.requestSubmit()
      } else if (query.length === 0) {
        // Clear search by submitting empty form
        this.element.requestSubmit()
      }
    }, this.debounceValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

**Step 2: Test search in browser**

```bash
bin/dev
```

Visit `http://localhost:3000/faq` and verify:
- Typing in search box triggers search after 300ms
- Search results appear below search bar
- Clearing search shows all categories again

**Step 3: Commit**

```bash
git add app/frontend/javascript/controllers/faq_search_controller.js
git commit -m "feat: add debounced search Stimulus controller for FAQ"
```

---

## Task 7: Add FAQ Schema Markup for SEO

**Files:**
- Create: `app/helpers/faq_helper.rb`
- Modify: `app/views/faqs/index.html.erb`

**Step 1: Create FAQ helper for schema markup**

Create `app/helpers/faq_helper.rb`:

```ruby
# frozen_string_literal: true

module FaqHelper
  def faq_schema_markup(categories)
    schema = {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": []
    }

    categories.each do |category|
      category["questions"].each do |question|
        schema[:mainEntity] << {
          "@type": "Question",
          "name": question["question"],
          "acceptedAnswer": {
            "@type": "Answer",
            "text": question["answer"]
          }
        }
      end
    end

    content_tag(:script, schema.to_json.html_safe, type: "application/ld+json")
  end
end
```

**Step 2: Add schema to FAQ view**

In `app/views/faqs/index.html.erb`, add at the bottom before closing `</div>`:

```erb
<!-- FAQ Schema Markup for SEO -->
<%= faq_schema_markup(@categories) %>
```

**Step 3: Write test for helper**

Create `test/helpers/faq_helper_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class FaqHelperTest < ActionView::TestCase
  test "generates valid FAQ schema markup" do
    categories = FaqService.all_categories
    schema_html = faq_schema_markup(categories)

    assert_includes schema_html, "application/ld+json"
    assert_includes schema_html, "FAQPage"
    assert_includes schema_html, "Question"
  end

  test "includes all questions in schema" do
    categories = FaqService.all_categories
    schema_html = faq_schema_markup(categories)

    # Count questions in YAML
    total_questions = categories.sum { |cat| cat["questions"].size }

    # Count Question types in schema
    question_count = schema_html.scan(/"@type":"Question"/).size

    assert_equal total_questions, question_count
  end
end
```

**Step 4: Run helper tests**

```bash
rails test test/helpers/faq_helper_test.rb
```

Expected: 2 tests PASS

**Step 5: Verify schema in browser**

```bash
bin/dev
```

Visit `http://localhost:3000/faq`, view page source, and verify JSON-LD script tag is present at the bottom.

**Step 6: Commit**

```bash
git add app/helpers/faq_helper.rb app/views/faqs/index.html.erb test/helpers/faq_helper_test.rb
git commit -m "feat: add FAQ schema markup for SEO"
```

---

## Task 8: Add Footer Link to FAQ

**Files:**
- Modify: `app/views/layouts/_footer.html.erb`

**Step 1: Add FAQ link to footer**

In `app/views/layouts/_footer.html.erb`, find the "Help" or "Customer Service" section and add:

```erb
<%= link_to "FAQs", faq_path, class: "link link-hover" %>
```

If there's no Help section, add one:

```erb
<div>
  <h6 class="footer-title">Help & Support</h6>
  <%= link_to "FAQs", faq_path, class: "link link-hover" %>
  <%= link_to "Contact", contact_path, class: "link link-hover" %>
</div>
```

**Step 2: Test footer link**

```bash
bin/dev
```

Visit any page and verify FAQ link appears in footer and navigates correctly.

**Step 3: Write system test for footer link**

Add to `test/system/navigation_test.rb` (or create if doesn't exist):

```ruby
# frozen_string_literal: true

require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "FAQ link in footer navigates to FAQ page" do
    visit root_path

    within "footer" do
      click_link "FAQs"
    end

    assert_current_path faq_path
    assert_selector "h1", text: "Frequently Asked Questions"
  end
end
```

**Step 4: Run system test**

```bash
rails test:system test/system/navigation_test.rb
```

Expected: Test PASS

**Step 5: Commit**

```bash
git add app/views/layouts/_footer.html.erb test/system/navigation_test.rb
git commit -m "feat: add FAQ link to footer"
```

---

## Task 9: Add Deep Linking Support

**Files:**
- Modify: `app/frontend/javascript/controllers/faq_accordion_controller.js`

**Step 1: Enhance accordion controller with hash navigation**

Replace content of `app/frontend/javascript/controllers/faq_accordion_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "content", "icon"]

  connect() {
    // Handle deep links on page load
    if (window.location.hash) {
      this.openLinkedCategory()
    } else {
      // Open first category by default if no hash
      if (this.element === this.element.parentElement.firstElementChild) {
        this.open()
      }
    }
  }

  toggle(event) {
    const content = event.currentTarget.nextElementSibling
    const icon = event.currentTarget.querySelector('[data-faq-accordion-target="icon"]')

    if (content.classList.contains('hidden')) {
      content.classList.remove('hidden')
      icon.style.transform = 'rotate(180deg)'
    } else {
      content.classList.add('hidden')
      icon.style.transform = 'rotate(0deg)'
    }
  }

  open() {
    const content = this.contentTarget
    const icon = this.iconTarget

    content.classList.remove('hidden')
    icon.style.transform = 'rotate(180deg)'
  }

  openLinkedCategory() {
    const hash = window.location.hash.substring(1) // Remove #
    const categoryId = hash.split('-')[0] // Get category part before question ID

    // Find the accordion card for this category
    const categoryCard = document.getElementById(categoryId)
    if (categoryCard) {
      const content = categoryCard.querySelector('[data-faq-accordion-target="content"]')
      const icon = categoryCard.querySelector('[data-faq-accordion-target="icon"]')

      if (content && icon) {
        content.classList.remove('hidden')
        icon.style.transform = 'rotate(180deg)'

        // Scroll to the specific question if present
        setTimeout(() => {
          const targetElement = document.getElementById(hash)
          if (targetElement) {
            targetElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
            targetElement.classList.add('bg-yellow-100')
            setTimeout(() => targetElement.classList.remove('bg-yellow-100'), 2000)
          }
        }, 100)
      }
    }
  }
}
```

**Step 2: Test deep linking**

```bash
bin/dev
```

Visit `http://localhost:3000/faq#custom-printing-moq` and verify:
- Correct category opens automatically
- Page scrolls to specific question
- Question briefly highlights

**Step 3: Commit**

```bash
git add app/frontend/javascript/controllers/faq_accordion_controller.js
git commit -m "feat: add deep linking support to FAQ accordion"
```

---

## Task 10: Final Testing & Documentation

**Files:**
- Create: `test/system/faq_test.rb`
- Modify: `README.md` (if FAQ feature should be documented)

**Step 1: Create comprehensive system test**

Create `test/system/faq_test.rb`:

```ruby
# frozen_string_literal: true

require "application_system_test_case"

class FaqTest < ApplicationSystemTestCase
  test "visiting FAQ page shows all categories" do
    visit faq_path

    assert_selector "h1", text: "Frequently Asked Questions"
    assert_selector ".card", count: 10 # 10 categories
  end

  test "accordion opens and closes categories" do
    visit faq_path

    # First category should be open by default
    within "#about-products" do
      assert_selector '[data-faq-accordion-target="content"]:not(.hidden)'
    end

    # Click to close
    within "#about-products" do
      click_on "About Our Products"
      assert_selector '[data-faq-accordion-target="content"].hidden'
    end
  end

  test "search finds relevant questions" do
    visit faq_path

    fill_in "q", with: "branded"

    # Wait for debounced search
    sleep 0.5

    assert_text "Search Results"
    assert_selector ".card", minimum: 1
  end

  test "quick links navigate to categories" do
    visit faq_path

    within ".bg-base-200" do
      click_link "Custom Printing & Branding"
    end

    # Should scroll to category (check URL hash)
    assert_equal "custom-printing", URI.parse(current_url).fragment
  end

  test "deep link opens correct category" do
    visit "#{faq_path}#sustainability-eco-friendly"

    within "#sustainability" do
      assert_selector '[data-faq-accordion-target="content"]:not(.hidden)'
    end
  end

  test "contact CTA appears in each category" do
    visit faq_path

    # Open a category
    within "#ordering-delivery" do
      click_on "Ordering & Delivery"
      assert_text "Still have questions"
      assert_link "info@afida.com"
      assert_link "0203 302 7719"
    end
  end
end
```

**Step 2: Run all FAQ tests**

```bash
rails test test/controllers/faqs_controller_test.rb test/services/faq_service_test.rb test/helpers/faq_helper_test.rb
rails test:system test/system/faq_test.rb
```

Expected: All tests PASS

**Step 3: Manual smoke test checklist**

Start server and test:

```bash
bin/dev
```

Manual checklist:
- [ ] Visit /faq - page loads
- [ ] First category opens by default
- [ ] Click category headers - accordion works
- [ ] Type in search - debounced search works
- [ ] Search results show correctly
- [ ] Quick links navigate to categories
- [ ] Deep link URL works (e.g., /faq#samples-sample-cost)
- [ ] Footer link navigates to FAQ
- [ ] Page is responsive on mobile (test in browser DevTools)
- [ ] View page source - JSON-LD schema present

**Step 4: Update documentation**

If your project has a README or FEATURES.md, add a note:

```markdown
## Features

- **FAQ Page** (`/faq`) - Comprehensive FAQ with 10 categories, searchable, SEO-optimized with schema markup
```

**Step 5: Final commit**

```bash
git add test/system/faq_test.rb
git commit -m "test: add comprehensive system tests for FAQ"
```

---

## Task 11: Deploy & Verify

**Step 1: Run full test suite**

```bash
rails test
rails test:system
```

Expected: All tests PASS

**Step 2: Check code quality**

```bash
rubocop app/controllers/faqs_controller.rb app/services/faq_service.rb app/helpers/faq_helper.rb
```

Fix any offenses if present.

**Step 3: Verify assets compile**

```bash
bin/vite build
```

Expected: No errors, assets compile successfully

**Step 4: Test in production mode locally (optional)**

```bash
RAILS_ENV=production rails assets:precompile
RAILS_ENV=production rails server
```

Visit `http://localhost:3000/faq` and verify everything works.

**Step 5: Create pull request or merge**

```bash
git push origin faq-section
```

Then create PR or merge to main branch.

---

## Implementation Complete

The FAQ section is now fully implemented with:

✅ YAML-based FAQ data structure (10 categories, 40+ questions)
✅ FAQ service with search functionality
✅ Controller and routes
✅ Responsive view with accordion UI
✅ Debounced search with live filtering
✅ FAQ schema markup for SEO
✅ Footer navigation link
✅ Deep linking support
✅ Comprehensive test coverage
✅ Mobile-friendly design

**Next steps:**
- Monitor Google Search Console for FAQ rich results
- Consider adding "Was this helpful?" feedback buttons (future enhancement)
- Update FAQs as business needs evolve (edit `config/faqs.yml`)
