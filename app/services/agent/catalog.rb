# frozen_string_literal: true

module Agent
  class Catalog
    PER_PAGE_DEFAULT = 25
    PER_PAGE_MAX = 100

    def initialize(base_url:)
      @base_url = base_url.to_s.delete_suffix("/")
    end

    def products(query: nil, category: nil, page: 1, per_page: nil)
      scope = Product.active.catalog_products.includes(:category, :product_family)
      scope = scope.search_ranked(query) if query.present?
      scope = scope.in_categories([ category ]) if category.present?
      scope = scope.order(:name, :id) if query.blank?

      page = page.to_i
      page = 1 if page < 1
      per_page = per_page.present? ? per_page.to_i.clamp(1, PER_PAGE_MAX) : PER_PAGE_DEFAULT
      total = scope.except(:order).count
      rows = scope.offset((page - 1) * per_page).limit(per_page)

      {
        "data" => rows.map { |product| serialize_product(product) },
        "meta" => { "page" => page, "per_page" => per_page, "total" => total }
      }
    end

    def product(slug)
      record = Product.active.catalog_products.includes(:category, :product_family).find_by!(slug: slug)
      { "data" => serialize_product(record, detailed: true) }
    end

    def categories
      records = Category.includes(:parent, :children).order(:position, :name)
      { "data" => records.map { |category| serialize_category(category) } }
    end

    def category(slug)
      record = Category.includes(:parent, :children).find_by!(slug: slug)
      { "data" => serialize_category(record) }
    end

    def serialize_product(product, detailed: false)
      payload = {
        "slug" => product.slug,
        "sku" => product.sku,
        "name" => product.display_name,
        "title" => product.generated_title,
        "url" => "#{@base_url}/products/#{product.slug}",
        "price" => price_payload(product),
        "pack_size" => product.pac_size,
        "in_stock" => product.in_stock?,
        "sample_eligible" => product.sample_eligible,
        "brand" => product.brand,
        "category" => product.category && {
          "slug" => product.category.slug,
          "name" => product.category.name,
          "url" => category_url(product.category)
        },
        "description" => product.description_short.presence || product.description_standard
      }
      return payload unless detailed

      payload.merge(
        "description_detailed" => product.description_detailed,
        "pricing_tiers" => product.pricing_tiers,
        "size" => product.size,
        "colour" => product.colour,
        "material" => product.material
      )
    end

    def serialize_category(category)
      {
        "slug" => category.slug,
        "name" => category.name,
        "url" => category_url(category),
        "parent" => category.parent && { "slug" => category.parent.slug, "name" => category.parent.name },
        "children" => category.children.sort_by { |child| [ child.position || 0, child.name ] }.map { |child|
          { "slug" => child.slug, "name" => child.name, "url" => category_url(child) }
        }
      }
    end

    private

    def price_payload(product)
      {
        "amount" => format("%.2f", product.price),
        "currency" => "GBP",
        "includes_vat" => false
      }
    end

    def category_url(category)
      if category.parent.present?
        "#{@base_url}/categories/#{category.parent.slug}/#{category.slug}"
      else
        "#{@base_url}/categories/#{category.slug}"
      end
    end
  end
end
