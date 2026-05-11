class ClearAllStaleProductMetaTitles < ActiveRecord::Migration[8.1]
  # Audit on 2026-05-11 against 669 production rows showed none of the existing
  # product meta_titles were human-curated. They were all output from a previous
  # generator formula (different word order, "Pizza Boxes" vs "Pizza Boxes 12in",
  # truncations at the admin 60-char limit, etc.). Clearing them so the new
  # Product#generated_meta_title becomes the source of truth across all PDPs.
  # The meta_title column stays available as a per-product override.

  def up
    Product.where.not(meta_title: [ nil, "" ]).update_all(meta_title: nil)
  end

  def down
    # No-op: the previous values were not human-curated, see class comment.
  end
end
