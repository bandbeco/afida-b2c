class StripBrandSuffixFromProductMetaTitles < ActiveRecord::Migration[8.1]
  # Removes the trailing " | Afida" suffix that was added to product meta titles
  # historically. Google appends the site name itself from WebSite schema, so the
  # manual suffix wasted character budget. Irreversible: there is no way to know
  # which titles had the suffix originally, but adding it back universally would
  # not be the desired state anyway.

  def up
    Product.where("meta_title LIKE ?", "% | Afida").find_each do |product|
      product.update_columns(meta_title: product.meta_title.sub(/\s*\|\s*Afida\s*\z/i, ""))
    end
  end

  def down
    # No-op: see class comment.
  end
end
