# A single row in the search results list, wrapping one product (a loose
# product, a brandable template, or a member of a ProductFamily), so both the
# header dropdown and the modal can render a uniform list.
#
# Search does not group products that share a ProductFamily: a family collects
# products that serve the same purpose, not size variants of one model, so
# folding them into one "N variants" row would misrepresent distinct products
# (issue #253). Every matching product is therefore its own row.
class SearchResultRow
  attr_reader :representative, :members

  def initialize(members)
    @members = members
    @representative = members.first
  end

  # The product this row links to and derives its photo/type/title from.
  def product
    representative
  end

  def brandable?
    representative.brandable?
  end

  def primary_photo
    representative.primary_photo
  end

  # Row heading.
  def title
    representative.generated_title
  end
end
