require "test_helper"

class CollectionsHelperTest < ActionView::TestCase
  test "vegware_filter_meta_title returns curated title for known sub-collection" do
    category = Category.new(name: "Cups & Drinks", slug: "cups-and-drinks")
    result = vegware_filter_meta_title(category)
    assert_equal "Vegware Cups & Drinks | Compostable Coffee Cups | Afida", result
  end

  test "vegware_filter_meta_title returns curated title for tableware" do
    category = Category.new(name: "Tableware", slug: "tableware")
    result = vegware_filter_meta_title(category)
    assert_equal "Vegware Tableware | Compostable Plates & Cutlery | Afida", result
  end

  test "vegware_filter_meta_title returns curated title for bags-and-wraps" do
    category = Category.new(name: "Bags & Wraps", slug: "bags-and-wraps")
    result = vegware_filter_meta_title(category)
    assert_equal "Vegware Bags & Wraps | Compostable Mailing Bags | Afida", result
  end

  test "vegware_filter_meta_title falls back to templated title for unknown slug" do
    category = Category.new(name: "Unknown Thing", slug: "unknown-thing")
    result = vegware_filter_meta_title(category)
    assert_equal "Vegware Unknown Thing | Eco-Friendly Packaging | Afida", result
  end

  test "vegware_filter_meta_description returns curated copy for cups-and-drinks" do
    category = Category.new(name: "Cups & Drinks", slug: "cups-and-drinks")
    result = vegware_filter_meta_description(category)
    assert_includes result.downcase, "vegware"
    assert_includes result.downcase, "cups"
    refute_includes result, "Browse our range of"
    assert result.length <= 160, "Description should be <= 160 chars (was #{result.length})"
  end

  test "vegware_filter_meta_description returns curated copy for tableware" do
    category = Category.new(name: "Tableware", slug: "tableware")
    result = vegware_filter_meta_description(category)
    assert_includes result.downcase, "plates"
    refute_includes result, "Browse our range of"
    assert result.length <= 160
  end

  test "vegware_filter_meta_description returns curated copy for bags-and-wraps" do
    category = Category.new(name: "Bags & Wraps", slug: "bags-and-wraps")
    result = vegware_filter_meta_description(category)
    assert_includes result.downcase, "mailing"
    refute_includes result, "Browse our range of"
    assert result.length <= 160
  end

  test "vegware_filter_meta_description returns curated copy for cold-food-and-salads" do
    category = Category.new(name: "Cold Food & Salads", slug: "cold-food-and-salads")
    result = vegware_filter_meta_description(category)
    assert_includes result.downcase, "salad"
    refute_includes result, "Browse our range of"
    assert result.length <= 160
  end

  test "vegware_filter_meta_description returns curated copy for hot-food" do
    category = Category.new(name: "Hot Food", slug: "hot-food")
    result = vegware_filter_meta_description(category)
    assert_includes result.downcase, "hot food"
    refute_includes result, "Browse our range of"
    assert result.length <= 160
  end

  test "vegware_filter_meta_description returns curated copy for supplies-and-essentials" do
    category = Category.new(name: "Supplies & Essentials", slug: "supplies-and-essentials")
    result = vegware_filter_meta_description(category)
    assert_includes result.downcase, "napkins"
    refute_includes result, "Browse our range of"
    assert result.length <= 160
  end

  test "vegware_filter_meta_description curated copies are unique across sub-collections" do
    slugs = %w[cups-and-drinks tableware bags-and-wraps cold-food-and-salads hot-food supplies-and-essentials]
    descriptions = slugs.map do |slug|
      category = Category.new(name: slug.titleize, slug: slug)
      vegware_filter_meta_description(category)
    end
    assert_equal descriptions.uniq.length, descriptions.length, "Each sub-collection should have a unique meta description"
  end

  test "vegware_filter_meta_description falls back to templated copy for unknown slug" do
    category = Category.new(name: "Unknown Thing", slug: "unknown-thing")
    result = vegware_filter_meta_description(category)
    assert_equal "Browse our range of Vegware Unknown Thing products. Plant-based, compostable packaging from the UK's leading eco-friendly supplier.", result
  end

  test "VEGWARE_FILTER_METAS covers every top-level category reachable via the Vegware filter" do
    vegware = Collection.find_by(slug: Collection::VEGWARE_SLUG)
    skip "No Vegware collection in this environment" unless vegware

    parent_ids = Category.joins(:products)
                         .where(products: { id: vegware.products.reorder(nil) })
                         .where.not(parent_id: nil)
                         .distinct
                         .pluck(:parent_id)
    reachable_slugs = Category.where(id: parent_ids).pluck(:slug)

    skip "No Vegware sub-categories present in fixtures/seed" if reachable_slugs.empty?

    missing = reachable_slugs - CollectionsHelper::VEGWARE_FILTER_METAS.keys
    assert_empty missing,
      "VEGWARE_FILTER_METAS is missing curated metas for: #{missing.inspect}. " \
      "Add an entry per slug or these pages will fall back to the templated boilerplate."
  end

  test "VEGWARE_FILTER_METAS entries all have a title and description within Google's limits" do
    CollectionsHelper::VEGWARE_FILTER_METAS.each do |slug, meta|
      assert meta[:title].present?, "VEGWARE_FILTER_METAS['#{slug}'] missing :title"
      assert meta[:description].present?, "VEGWARE_FILTER_METAS['#{slug}'] missing :description"

      rendered_title_length = "#{meta[:title]} | Afida".length
      assert rendered_title_length <= 60,
        "VEGWARE_FILTER_METAS['#{slug}'] rendered title is #{rendered_title_length} chars (Google truncates past ~60). Title: '#{meta[:title]} | Afida'"

      assert meta[:description].length <= 160,
        "VEGWARE_FILTER_METAS['#{slug}'] description is #{meta[:description].length} chars (max 160)"
    end
  end
end
