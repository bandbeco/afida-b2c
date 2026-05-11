class ClearAllStaleProductMetaDescriptions < ActiveRecord::Migration[8.1]
  # Audit on 2026-05-11 against 670 production rows showed none of the existing
  # product meta_descriptions were human-curated. They were two flavours of
  # auto-generated boilerplate ("Shop {name}. Cases of {qty}. Free UK delivery
  # over £100. Order at Afida." for 571 rows; "{name}. Pack of {qty}. Wholesale
  # pricing. Free UK delivery over £100." for the rest). Clearing them so the
  # new Product#generated_meta_description becomes the source of truth across
  # all PDPs. The meta_description column stays available as a per-product
  # override.

  def up
    Product.where.not(meta_description: [ nil, "" ]).update_all(meta_description: nil)
  end

  def down
    # No-op: the previous values were not human-curated, see class comment.
  end
end
