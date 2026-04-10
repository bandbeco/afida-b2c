# frozen_string_literal: true

class AddStructuredContentToBlogPosts < ActiveRecord::Migration[8.1]
  def change
    change_table :blog_posts, bulk: true do |t|
      # Text/string fields for structured template sections
      t.text :intro
      t.string :top_cta_heading
      t.text :top_cta_body
      t.string :branding_heading
      t.text :branding_body
      t.string :final_cta_heading
      t.text :final_cta_body
      t.text :conclusion
      t.string :primary_keyword

      # JSONB arrays for structured content blocks
      t.jsonb :decision_factors, null: false, default: []
      t.jsonb :buyer_setups, null: false, default: []
      t.jsonb :recommended_options, null: false, default: []
      t.jsonb :faq_items, null: false, default: []
      t.jsonb :top_cta_buttons, null: false, default: []
      t.jsonb :final_cta_buttons, null: false, default: []
      t.jsonb :internal_link_targets, null: false, default: []
      t.jsonb :target_category_slugs, null: false, default: []
      t.jsonb :target_collection_slugs, null: false, default: []
      t.jsonb :target_product_slugs, null: false, default: []
      t.jsonb :secondary_keywords, null: false, default: []
    end
  end
end
