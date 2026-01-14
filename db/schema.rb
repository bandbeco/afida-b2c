# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_14_154905) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "city", limit: 100, null: false
    t.string "company_name", limit: 100
    t.string "country", limit: 2, default: "GB", null: false
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.string "line1", limit: 200, null: false
    t.string "line2", limit: 100
    t.string "nickname", limit: 50, null: false
    t.string "phone", limit: 30
    t.string "postcode", limit: 20, null: false
    t.string "recipient_name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "default"], name: "idx_addresses_user_default", where: "(\"default\" = true)"
    t.index ["user_id", "line1", "postcode"], name: "index_addresses_on_user_line1_postcode"
    t.index ["user_id"], name: "index_addresses_on_user_id"
    t.index ["user_id"], name: "index_addresses_on_user_id_where_default", unique: true, where: "(\"default\" = true)"
  end

  create_table "blog_posts", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.text "excerpt"
    t.text "meta_description"
    t.string "meta_title"
    t.boolean "published", default: false, null: false
    t.datetime "published_at"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["published"], name: "index_blog_posts_on_published"
    t.index ["published_at"], name: "index_blog_posts_on_published_at"
    t.index ["slug"], name: "index_blog_posts_on_slug", unique: true
  end

  create_table "branded_product_prices", force: :cascade do |t|
    t.integer "case_quantity", null: false
    t.datetime "created_at", null: false
    t.decimal "price_per_unit", precision: 10, scale: 4, null: false
    t.bigint "product_id", null: false
    t.integer "quantity_tier", null: false
    t.string "size", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "size", "quantity_tier"], name: "index_branded_prices_uniqueness", unique: true
    t.index ["product_id"], name: "index_branded_product_prices_on_product_id"
  end

  create_table "cart_items", force: :cascade do |t|
    t.decimal "calculated_price", precision: 10, scale: 2
    t.bigint "cart_id", null: false
    t.jsonb "configuration", default: {}
    t.datetime "created_at", null: false
    t.boolean "is_sample", default: false, null: false
    t.decimal "price", precision: 10, scale: 4, null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "price"], name: "index_cart_items_on_cart_id_and_price"
    t.index ["cart_id", "product_id"], name: "index_cart_items_on_cart_id_and_product_id"
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["configuration"], name: "index_cart_items_on_configuration", using: :gin
    t.index ["is_sample"], name: "index_cart_items_on_is_sample"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
  end

  create_table "carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["created_at"], name: "index_carts_on_created_at"
    t.index ["user_id"], name: "index_carts_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "meta_description"
    t.string "meta_title"
    t.string "name"
    t.integer "position", null: false
    t.integer "products_count", default: 0, null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_categories_on_position"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.jsonb "configuration", default: {}
    t.datetime "created_at", null: false
    t.boolean "is_sample", default: false, null: false
    t.decimal "line_total", precision: 10, scale: 2, null: false
    t.bigint "order_id", null: false
    t.integer "pac_size"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "product_id", null: false
    t.string "product_name", null: false
    t.string "product_sku", null: false
    t.integer "quantity", null: false
    t.datetime "updated_at", null: false
    t.index ["configuration"], name: "index_order_items_on_configuration", using: :gin
    t.index ["is_sample"], name: "index_order_items_on_is_sample"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "branded_order_status"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "ga4_purchase_tracked_at"
    t.string "order_number", null: false
    t.bigint "organization_id"
    t.bigint "placed_by_user_id"
    t.bigint "reorder_schedule_id"
    t.string "shipping_address_line1", null: false
    t.string "shipping_address_line2"
    t.decimal "shipping_amount", precision: 10, scale: 2, null: false
    t.string "shipping_city", null: false
    t.string "shipping_country", null: false
    t.string "shipping_name", null: false
    t.string "shipping_postal_code", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_session_id", null: false
    t.decimal "subtotal_amount", precision: 10, scale: 2, null: false
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.decimal "vat_amount", precision: 10, scale: 2, null: false
    t.index ["branded_order_status"], name: "index_orders_on_branded_order_status"
    t.index ["email"], name: "index_orders_on_email"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["organization_id", "created_at"], name: "index_orders_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_orders_on_organization_id"
    t.index ["placed_by_user_id"], name: "index_orders_on_placed_by_user_id"
    t.index ["reorder_schedule_id"], name: "index_orders_on_reorder_schedule_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["stripe_session_id"], name: "index_orders_on_stripe_session_id", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "billing_email", null: false
    t.datetime "created_at", null: false
    t.jsonb "default_shipping_address", default: {}
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["billing_email"], name: "index_organizations_on_billing_email"
  end

  create_table "pending_orders", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "expired_at"
    t.jsonb "items_snapshot", default: {}, null: false
    t.bigint "order_id"
    t.bigint "reorder_schedule_id", null: false
    t.date "scheduled_for", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_pending_orders_on_order_id"
    t.index ["reorder_schedule_id", "scheduled_for"], name: "index_pending_orders_unique_pending_per_schedule", unique: true, where: "(status = 0)"
    t.index ["reorder_schedule_id"], name: "index_pending_orders_on_reorder_schedule_id"
    t.index ["scheduled_for"], name: "index_pending_orders_on_scheduled_for"
    t.index ["status", "scheduled_for"], name: "index_pending_orders_on_status_and_scheduled_for"
  end

  create_table "product_compatible_lids", force: :cascade do |t|
    t.bigint "compatible_lid_id", null: false
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.bigint "product_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["compatible_lid_id"], name: "index_product_compatible_lids_on_compatible_lid_id"
    t.index ["product_id", "compatible_lid_id"], name: "index_product_compatible_lids_on_product_and_lid", unique: true
    t.index ["product_id", "sort_order"], name: "index_product_compatible_lids_on_product_id_and_sort_order"
    t.index ["product_id"], name: "index_product_compatible_lids_on_product_id"
  end

  create_table "product_families", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_product_families_on_slug", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "b2b_priority"
    t.boolean "best_seller", default: false
    t.bigint "category_id"
    t.string "colour"
    t.datetime "created_at", null: false
    t.integer "depth_in_mm"
    t.text "description_detailed"
    t.text "description_short"
    t.text "description_standard"
    t.integer "diameter_in_mm"
    t.boolean "featured", default: false
    t.string "gtin"
    t.integer "height_in_mm"
    t.integer "length_in_mm"
    t.string "material"
    t.text "meta_description"
    t.string "meta_title"
    t.string "name", null: false
    t.bigint "organization_id"
    t.integer "pac_size"
    t.bigint "parent_product_id"
    t.integer "position", default: 0
    t.decimal "price", precision: 10, scale: 2, null: false
    t.jsonb "pricing_tiers"
    t.bigint "product_family_id"
    t.string "product_type", default: "standard"
    t.boolean "sample_eligible", default: true, null: false
    t.string "size"
    t.string "sku", null: false
    t.string "slug", limit: 255, null: false
    t.integer "stock_quantity", default: 0
    t.datetime "updated_at", null: false
    t.decimal "vat_rate", precision: 6, scale: 4
    t.integer "volume_in_ml"
    t.integer "weight_in_g"
    t.integer "width_in_mm"
    t.index ["active"], name: "index_products_on_active"
    t.index ["best_seller"], name: "index_products_on_best_seller"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["featured"], name: "index_products_on_featured"
    t.index ["gtin"], name: "index_products_on_gtin", unique: true, where: "(gtin IS NOT NULL)"
    t.index ["organization_id"], name: "index_products_on_organization_id"
    t.index ["product_family_id"], name: "index_products_on_product_family_id"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["sample_eligible"], name: "index_products_on_sample_eligible"
    t.index ["slug"], name: "index_products_on_slug", unique: true
  end

  create_table "reorder_schedule_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.bigint "reorder_schedule_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_reorder_schedule_items_on_product_id"
    t.index ["reorder_schedule_id", "product_id"], name: "idx_schedule_items_unique", unique: true
    t.index ["reorder_schedule_id"], name: "index_reorder_schedule_items_on_reorder_schedule_id"
  end

  create_table "reorder_schedules", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.string "card_brand"
    t.string "card_last4"
    t.datetime "created_at", null: false
    t.integer "frequency", null: false
    t.date "next_scheduled_date", null: false
    t.datetime "paused_at"
    t.integer "status", default: 0, null: false
    t.string "stripe_payment_method_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["next_scheduled_date"], name: "index_reorder_schedules_on_next_scheduled_date"
    t.index ["status", "next_scheduled_date"], name: "index_reorder_schedules_on_status_and_next_scheduled_date"
    t.index ["user_id"], name: "index_reorder_schedules_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_sessions_on_created_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "url_redirects", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "hit_count", default: 0, null: false
    t.string "source_path", limit: 500, null: false
    t.string "target_slug", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.jsonb "variant_params", default: {}, null: false
    t.index "lower((source_path)::text)", name: "index_legacy_redirects_on_lower_legacy_path", unique: true
    t.index ["active"], name: "index_url_redirects_on_active"
    t.index ["hit_count"], name: "index_url_redirects_on_hit_count"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "default_billing_address", default: {}, null: false
    t.jsonb "default_shipping_address", default: {}, null: false
    t.string "email_address", null: false
    t.boolean "email_address_verified", default: false
    t.string "first_name"
    t.string "last_name"
    t.bigint "organization_id"
    t.string "password_digest", null: false
    t.string "role"
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["organization_id", "role"], name: "index_users_on_organization_id_and_role"
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "users"
  add_foreign_key "branded_product_prices", "products"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "organizations"
  add_foreign_key "orders", "reorder_schedules"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "placed_by_user_id"
  add_foreign_key "pending_orders", "orders"
  add_foreign_key "pending_orders", "reorder_schedules"
  add_foreign_key "product_compatible_lids", "products"
  add_foreign_key "product_compatible_lids", "products", column: "compatible_lid_id"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "organizations"
  add_foreign_key "products", "product_families"
  add_foreign_key "reorder_schedule_items", "products"
  add_foreign_key "reorder_schedule_items", "reorder_schedules"
  add_foreign_key "reorder_schedules", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "organizations"
end
