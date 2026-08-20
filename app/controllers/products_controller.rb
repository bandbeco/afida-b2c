# Controller for product pages
#
# Product is the main sellable entity. Products can optionally belong to
# a ProductFamily for grouping related products (e.g., different sizes
# of the same cup type). Sibling products in the same family are shown
# in a "See Also" section on the product page.
#
class ProductsController < ApplicationController
  allow_unauthenticated_access

  # Attach rows shown before the buy box gets too long to scan. Containers stop
  # here; lid pages keep the rest behind a disclosure.
  ATTACH_ROWS_VISIBLE = 4

  def index
    @products = Product.active
                       .standard
                       .includes(:category, product_photo_attachment: :blob)
                       .order(position: :asc, id: :asc)
  end

  def show
    @product = Product.active
                      .includes(:category, :product_family, :product_compatible_lids,
                                compatible_lids: [
                                  { product_photo_attachment: :blob },
                                  { lifestyle_photo_attachment: :blob }
                                ],
                                compatible_containers: [
                                  { product_photo_attachment: :blob },
                                  { lifestyle_photo_attachment: :blob }
                                ])
                      .find_by!(slug: params[:slug])

    # Redirect branded product templates to /branded-products/:slug
    if @product.customizable_template?
      return redirect_to branded_product_path(@product.slug), status: :moved_permanently
    end

    @category = @product.category

    # Delivery promise shown next to the buy box, computed server-side so the
    # product page and order confirmation share one source of truth.
    @delivery_estimate = DeliveryEstimate.new(Time.current)

    # The attach block, in whichever direction this product has mappings. The
    # curated container -> lid join is the sole source of truth: containers
    # offer their lids (curation keeps that list short, so it is capped),
    # lids offer the containers they fit (a lid can fit a dozen trays, and
    # hiding the buyer's tray would read as "doesn't fit", so the full list
    # renders with the tail behind a disclosure).
    active_lids = @product.compatible_lids.select(&:active?)
    @default_lid_id = @product.product_compatible_lids.find(&:default?)&.compatible_lid_id
    # The curated default leads: it is the lid most buyers of this container
    # take, so it earns the first row and the popularity cue.
    @compatible_products = active_lids
      .each_with_index
      .sort_by { |lid, index| [ lid.id == @default_lid_id ? 0 : 1, index ] }
      .map(&:first)
      .first(ATTACH_ROWS_VISIBLE)
    @compatible_containers = @compatible_products.any? ? [] : @product.compatible_containers.to_a

    # Related products from the same family (for "See Also" section)
    @related_products = @product.siblings(limit: 4)
                                .includes(product_photo_attachment: :blob,
                                          lifestyle_photo_attachment: :blob)

    # Fallback to same category if no family siblings
    if @related_products.empty?
      @related_products = Product.active
                                 .catalog_products
                                 .where(category: @category)
                                 .where.not(id: @product.id)
                                 .includes(product_photo_attachment: :blob,
                                           lifestyle_photo_attachment: :blob)
                                 .limit(4)
    end
  rescue ActiveRecord::RecordNotFound
    render file: Rails.root.join("public", "404.html"), status: :not_found, layout: false
  end

  def quick_add
    @product = Product.active.catalog_products.find_by!(slug: params[:slug])

    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    render layout: false  # Turbo Frame content only
  end
end
