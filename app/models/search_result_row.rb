# A single row in the search results list. Wraps either one product (a loose
# product, a brandable template, or a familied product that was the only match
# in its family) or a collapsed product family (several catalog variants that
# share a ProductFamily), so both the header dropdown and the modal can render
# a uniform list.
#
# For a collapsed family, the representative is the best-ranked matching member,
# which is also the product the row links to (mirroring how the family-grouped
# listing pages lead with the first product of a family run).
class SearchResultRow
  attr_reader :representative, :members

  # Collapses an ordered, relevance-ranked list of products into rows.
  # Non-brandable products that share a ProductFamily and appear more than once
  # are folded into one family row; everything else stays an individual row.
  # Row order follows the first (best-ranked) appearance of each product/family.
  def self.collapse(products)
    rows = []
    family_rows = {}

    products.each do |product|
      family_id = collapsible_family_id(product)

      if family_id.nil?
        rows << new([ product ])
      elsif family_rows.key?(family_id)
        family_rows[family_id].members << product
      else
        row = new([ product ])
        family_rows[family_id] = row
        rows << row
      end
    end

    rows
  end

  # A product collapses only when it belongs to a family and is not a brandable
  # template (brandable rows always stay individual, per issue #247).
  def self.collapsible_family_id(product)
    return nil if product.brandable?

    product.product_family_id
  end

  def initialize(members)
    @members = members
    @representative = members.first
  end

  # True once more than one member has folded into this family row.
  def family?
    members.size > 1 && representative.product_family.present?
  end

  # The product this row links to and derives its photo/type from.
  def product
    representative
  end

  def brandable?
    representative.brandable?
  end

  def primary_photo
    representative.primary_photo
  end

  # Row heading: the family name for a collapsed family, otherwise the
  # representative product's generated title.
  def title
    family? ? representative.product_family.name : representative.generated_title
  end

  # Distinct member sizes ordered smallest to largest.
  def sizes
    members.map(&:size).compact_blank.uniq.sort_by { |size| size_sort_key(size) }
  end

  # "4oz - 16oz" (or a single size), nil when no member carries a size.
  def size_range
    range = sizes
    return nil if range.empty?
    return range.first if range.size == 1

    "#{range.first} - #{range.last}"
  end

  def variant_count
    members.size
  end

  # [[size, member], ...] for each distinct member size, ordered smallest to
  # largest. When several members share a size (e.g. colours of the same size),
  # the cheapest one represents it, so a size chip links to a page consistent
  # with the row's "from" price framing. Lets the modal turn the size range into
  # per-variant links, since each variant has its own page.
  #
  # Members with a blank size are excluded (they carry no size to label a chip);
  # they stay reachable through the row's heading/representative link, and the
  # honest "N variants" count still includes them. Splitting an over-broad family
  # so its variants share a clean size axis is a data fix, not a code one.
  def size_variants
    @size_variants ||= members
      .select { |member| member.size.present? }
      .group_by(&:size)
      .map { |size, group| [ size, group.min_by(&:price) ] }
      .sort_by { |size, _member| size_sort_key(size) }
  end

  # The cheapest member price, used for a family row's "from" price.
  def from_price
    members.map(&:price).min
  end

  # The member offering the cheapest achievable per-unit price, so a family
  # row can quote a per-unit "from" figure consistent with the card helper.
  def cheapest_per_unit_member
    members.min_by(&:best_unit_price)
  end

  private

  # Orders sizes smallest to largest. Sizes with a leading number (the common
  # "8oz", "12oz / 340ml", "2-Cup") sort first, numerically by that number, then
  # alphabetically for equal numbers; sizes with no leading number ("Small",
  # "Medium") sort after them, alphabetically. This keeps ordering deterministic
  # instead of collapsing every non-numeric or bare size to 0 with `to_i`.
  # Note: it does not normalise units, so a family mixing oz and litres can still
  # order oddly; the real fix for such a family is splitting it (a data fix).
  def size_sort_key(size)
    leading_number = size[/\A\s*(\d+(?:\.\d+)?)/, 1]
    if leading_number
      [ 0, leading_number.to_f, size.downcase ]
    else
      [ 1, 0.0, size.downcase ]
    end
  end
end
