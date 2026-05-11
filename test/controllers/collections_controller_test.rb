require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @collection = collections(:coffee_shop_essentials)
    @empty_collection = collections(:empty_collection)
    @sample_pack = collections(:coffee_shop_sample_pack)
  end

  # ==========================================================================
  # GET /collections (index)
  # ==========================================================================

  test "index shows featured collections" do
    get collections_url
    assert_response :success
    assert_match @collection.name, response.body
  end

  test "index excludes sample pack collections" do
    get collections_url
    assert_response :success
    assert_no_match @sample_pack.name, response.body
  end

  test "index is publicly accessible" do
    get collections_url
    assert_response :success
  end

  test "index is accessible to authenticated users" do
    sign_in_as(users(:one))
    get collections_url
    assert_response :success
  end

  # ==========================================================================
  # GET /collections/:slug (show)
  # ==========================================================================

  test "show displays collection by slug" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_match @collection.name, response.body
  end

  test "show displays collection products" do
    get collection_url(@collection.slug)
    assert_response :success
    # Collection has products from fixtures
    @collection.products.active.each do |product|
      assert_match product.generated_title, response.body
    end
  end

  test "show displays collection description" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_match @collection.description, response.body
  end

  test "show renders empty state for empty collection" do
    get collection_url(@empty_collection.slug)
    assert_response :success
    # Should show empty state message
    assert_match(/no products/i, response.body)
  end

  test "show is publicly accessible" do
    get collection_url(@collection.slug)
    assert_response :success
  end

  test "show is accessible to authenticated users" do
    sign_in_as(users(:one))
    get collection_url(@collection.slug)
    assert_response :success
  end

  test "show returns 404 for non-existent slug" do
    get "/collections/non-existent-collection"
    assert_response :not_found
  end

  # ==========================================================================
  # SEO Tests
  # ==========================================================================

  test "show includes meta title" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "title", text: /#{@collection.meta_title}/
  end

  test "show includes meta description" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "meta[name=description]" do |elements|
      assert elements.any? { |e| e[:content].include?(@collection.meta_description) }
    end
  end

  test "show includes structured data" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "script[type='application/ld+json']"
  end

  test "show includes breadcrumbs" do
    get collection_url(@collection.slug)
    assert_response :success
    # Breadcrumb should include home and collection name
    assert_match "Home", response.body
    assert_match @collection.name, response.body
  end

  # ==========================================================================
  # Buying guide
  # ==========================================================================

  test "show renders buying guide when present" do
    collection = collections(:collection_with_buying_guide)
    get collection_url(collection.slug)
    assert_response :success
    assert_select "section.buying-guide"
    assert_select ".prose"
  end

  test "show does not render buying guide section when absent" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "section.buying-guide", count: 0
  end

  # ==========================================================================
  # FAQs
  # ==========================================================================

  test "show renders FAQ section when faqs are present" do
    @collection.update!(faqs: [
      { "question" => "Do you offer samples?", "answer" => "Yes, free samples." },
      { "question" => "What is the delivery time?", "answer" => "Next day before 1pm cutoff." }
    ])
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "section.collection-faqs"
    assert_match "Do you offer samples?", response.body
    assert_match "What is the delivery time?", response.body
  end

  test "show emits FAQPage schema when faqs are present" do
    @collection.update!(faqs: [
      { "question" => "Do you offer samples?", "answer" => "Yes, free samples." }
    ])
    get collection_url(@collection.slug)
    assert_response :success
    assert_match '"@type":"FAQPage"', response.body
    assert_match "Do you offer samples?", response.body
  end

  test "show does not render FAQ section when faqs are empty" do
    @collection.update!(faqs: [])
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "section.collection-faqs", count: 0
    assert_no_match(/"@type":"FAQPage"/, response.body)
  end

  # ==========================================================================
  # Samples CTA
  # ==========================================================================

  test "show renders samples CTA linking to /samples" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_select "section.collection-samples-cta" do
      assert_select "a[href=?]", samples_path
    end
  end

  test "samples CTA does not promise free delivery" do
    get collection_url(@collection.slug)
    assert_response :success
    assert_no_match(/we cover delivery/i, response.body)
  end

  # ==========================================================================
  # URL Tests
  # ==========================================================================

  test "collection URLs use SEO-friendly slugs" do
    get collection_url(@collection.slug)
    assert_response :success
    # URL should contain the slug, not numeric ID
    assert_includes request.path, @collection.slug
  end

  # ==========================================================================
  # Product ordering: family then capacity
  # ==========================================================================

  test "products are ordered by family sort_order then volume_in_ml" do
    paper = product_families(:paper_lids)
    black = product_families(:recyclable_lids_black)
    white = product_families(:recyclable_lids_white)

    paper.update!(sort_order: 10)
    black.update!(sort_order: 20)
    white.update!(sort_order: 30)

    products(:paper_lid_80mm).update!(volume_in_ml: 227)
    products(:paper_lid_90mm).update!(volume_in_ml: 340)

    products(:recyclable_lid_black_62mm).update!(volume_in_ml: 114)
    products(:recyclable_lid_black_80mm).update!(volume_in_ml: 227)
    products(:recyclable_lid_black_90mm).update!(volume_in_ml: 340)

    products(:recyclable_lid_white_62mm).update!(volume_in_ml: 114)
    products(:recyclable_lid_white_80mm).update!(volume_in_ml: 227)
    products(:recyclable_lid_white_90mm).update!(volume_in_ml: 340)

    collection = make_collection("Lids Collection")
    add_to_collection(collection, products(:paper_lid_80mm))
    add_to_collection(collection, products(:paper_lid_90mm))
    add_to_collection(collection, products(:recyclable_lid_black_62mm))
    add_to_collection(collection, products(:recyclable_lid_black_80mm))
    add_to_collection(collection, products(:recyclable_lid_black_90mm))
    add_to_collection(collection, products(:recyclable_lid_white_62mm))
    add_to_collection(collection, products(:recyclable_lid_white_80mm))
    add_to_collection(collection, products(:recyclable_lid_white_90mm))
    # Family-less product to verify it sorts last.
    add_to_collection(collection, products(:flat_lid_8oz))

    get collection_url(collection.slug)
    assert_response :success

    products = controller.view_assigns["products"].to_a
    family_keys = products.map { |p| p.product_family&.slug }

    paper_index = family_keys.index("paper-sip-lids-for-hot-cups")
    black_index = family_keys.index("recyclable-sip-lids-black")
    white_index = family_keys.index("recyclable-sip-lids-white")

    assert paper_index < black_index, "paper family must come before black family"
    assert black_index < white_index, "black family must come before white family"

    black_volumes = products
                      .select { |p| p.product_family&.slug == "recyclable-sip-lids-black" }
                      .map(&:volume_in_ml)
    assert_equal black_volumes.sort, black_volumes,
                 "black family products must be in ascending volume_in_ml order"

    last_with_family = products.rindex { |p| p.product_family_id.present? }
    first_without_family = products.index { |p| p.product_family_id.nil? }
    if last_with_family && first_without_family
      assert first_without_family > last_with_family,
             "family-less products must appear after all family-grouped products"
    end
  end

  test "within a family, products group by name first then ascending volume" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    collection = make_collection("Name+Volume Test")

    double_8 = make_product_in_collection(collection, family, "Double Wall Cups", 227)
    double_12 = make_product_in_collection(collection, family, "Double Wall Cups", 340)
    single_8 = make_product_in_collection(collection, family, "Single Wall Cups", 227)
    single_12 = make_product_in_collection(collection, family, "Single Wall Cups", 340)

    get collection_url(collection.slug)
    assert_response :success

    products = controller.view_assigns["products"].to_a
    ids = products.map(&:id)

    assert_equal [ double_8.id, double_12.id, single_8.id, single_12.id ], ids,
                 "products should be grouped by name first, then ascending volume_in_ml"
  end

  test "within a family, products group by material then colour, with sizes ascending in each colour" do
    family = product_families(:paper_lids)
    family.update!(sort_order: 5)

    collection = make_collection("Variant Test")

    black_4 = make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "Black", "rPET", 118)
    black_8 = make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "Black", "rPET", 227)
    white_4 = make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "White", "rPET", 118)
    white_8 = make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "White", "rPET", 227)
    bag_8 = make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "White", "Bagasse", 227)

    get collection_url(collection.slug)
    assert_response :success

    products = controller.view_assigns["products"].to_a
    ids = products.map(&:id)

    assert_equal [ bag_8.id, black_4.id, black_8.id, white_4.id, white_8.id ], ids
  end

  # ==========================================================================
  # Family group headers in the rendered view
  # ==========================================================================

  test "renders an h2 family heading for each multi-product family on a collection" do
    paper = product_families(:paper_lids)
    black = product_families(:recyclable_lids_black)
    white = product_families(:recyclable_lids_white)

    paper.update!(sort_order: 10)
    black.update!(sort_order: 20)
    white.update!(sort_order: 30)

    collection = make_collection("Multi Family Headings Test")
    add_to_collection(collection, products(:paper_lid_80mm))
    add_to_collection(collection, products(:paper_lid_90mm))
    add_to_collection(collection, products(:recyclable_lid_black_62mm))
    add_to_collection(collection, products(:recyclable_lid_black_80mm))
    add_to_collection(collection, products(:recyclable_lid_white_62mm))
    add_to_collection(collection, products(:recyclable_lid_white_80mm))

    get collection_url(collection.slug)
    assert_response :success

    assert_select ".product-family-heading",
                  text: /#{Regexp.escape(paper.name)}/
    assert_select ".product-family-heading",
                  text: /#{Regexp.escape(black.name)}/
    assert_select ".product-family-heading",
                  text: /#{Regexp.escape(white.name)}/
  end

  test "does not render an h2 heading for products without a product_family on a collection" do
    paper = product_families(:paper_lids)
    paper.update!(sort_order: 10)

    collection = make_collection("Family-less Headings Test")
    add_to_collection(collection, products(:paper_lid_80mm))
    add_to_collection(collection, products(:paper_lid_90mm))
    add_to_collection(collection, products(:flat_lid_8oz))
    add_to_collection(collection, products(:domed_lid_8oz))

    get collection_url(collection.slug)
    assert_response :success

    assert_select ".product-family-heading", text: /Flat Lid/, count: 0
    assert_select ".product-family-heading", text: /Domed Lid/, count: 0
  end

  test "falls back to a flat grid when no name+material has 2+ products on the collection page" do
    family_a = product_families(:single_wall_cups)
    family_a.update!(sort_order: 5)
    family_b = product_families(:paper_lids)
    family_b.update!(sort_order: 6)

    collection = make_collection("Miscellaneous Collection")

    make_variant_in_collection(collection, family_a, "Item A", "White", "Paper", 227)
    make_variant_in_collection(collection, family_b, "Item B", "Black", "rPET", 340)
    make_variant_in_collection(collection, family_a, "Item C", "Kraft", "Bagasse", 455)

    get collection_url(collection.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 0
    assert_select ".product-family-heading", count: 0
  end

  test "renders one centered flex row per name+material run on a collection" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    collection = make_collection("Row Break Collection")

    make_variant_in_collection(collection, family, "Double Wall Cups", "White", "Paper", 227)
    make_variant_in_collection(collection, family, "Double Wall Cups", "White", "Paper", 340)
    make_variant_in_collection(collection, family, "Single Wall Cups", "White", "Paper", 227)
    make_variant_in_collection(collection, family, "Single Wall Cups", "White", "Paper", 340)

    get collection_url(collection.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 2
  end

  test "merges a singleton colour row into the previous multi-card row of the same name+material on a collection" do
    family = product_families(:paper_lids)
    family.update!(sort_order: 5)

    collection = make_collection("Backward Merge Collection")

    make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "Black", "PP", 340)
    make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "Black", "PP", 455)
    make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "White", "PP", 340)

    get collection_url(collection.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 1
  end

  test "merges singleton colour rows into the next colour row of the same name+material on a collection" do
    family = product_families(:paper_lids)
    family.update!(sort_order: 5)

    collection = make_collection("Singleton Merge Collection")

    make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "Black", "PP", 340)
    make_variant_in_collection(collection, family, "Coffee Cup Sip Lids", "White", "PP", 340)

    get collection_url(collection.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 1
  end

  test "renders solo unmergeable products inline with the grid on a collection, not as full-width rows" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    collection = make_collection("Mixed Solo And Pair Collection")

    make_variant_in_collection(collection, family, "Cups", "White", "Paper", 227)
    make_variant_in_collection(collection, family, "Cups", "White", "Paper", 340)
    make_variant_in_collection(collection, family, "Burger Tray", "Black", "Paperboard", nil)
    make_variant_in_collection(collection, family, "Carry Pack", "Kraft", "Card", nil)
    make_variant_in_collection(collection, family, "Takeaway Box", "White", "Card", nil)
    make_variant_in_collection(collection, family, "Chips Bag", "White", "Paper", nil)

    get collection_url(collection.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 1
  end

  test "renders a single centered row on a collection when all products share name and material" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    collection = make_collection("Same-Name Collection")

    make_variant_in_collection(collection, family, "Cups", "White", "Paper", 227)
    make_variant_in_collection(collection, family, "Cups", "White", "Paper", 340)
    make_variant_in_collection(collection, family, "Cups", "White", "Paper", 455)

    get collection_url(collection.slug)
    assert_response :success

    assert_select "div.col-span-full.flex.justify-center", count: 1
  end

  test "does not render any family heading on a collection when only one family is on the page" do
    family = product_families(:single_wall_cups)
    family.update!(sort_order: 5)

    collection = make_collection("Single-Family Collection")

    make_variant_in_collection(collection, family, "Cups", "White", "Paper", 227)
    make_variant_in_collection(collection, family, "Cups", "White", "Paper", 340)

    get collection_url(collection.slug)
    assert_response :success

    assert_select ".product-family-heading", count: 0
  end

  # ==========================================================================
  # Vegware category_filter action shares the same grouping/ordering logic.
  # ==========================================================================

  test "vegware category_filter orders products by family sort_order then volume_in_ml" do
    vegware = collections(:vegware)
    parent = categories(:parent_hot_food)
    leaf = categories(:child_pizza_boxes)

    paper = product_families(:paper_lids)
    black = product_families(:recyclable_lids_black)
    paper.update!(sort_order: 10)
    black.update!(sort_order: 20)

    p_paper_low = make_filter_product(vegware, leaf, paper, "Paper Lid", 227)
    p_paper_high = make_filter_product(vegware, leaf, paper, "Paper Lid", 340)
    p_black_low = make_filter_product(vegware, leaf, black, "Black Lid", 227)
    p_black_high = make_filter_product(vegware, leaf, black, "Black Lid", 340)

    get category_filter_collection_url(vegware, category_slug: parent.slug)
    assert_response :success

    products = controller.view_assigns["products"].to_a
    family_keys = products.map { |p| p.product_family&.slug }

    paper_index = family_keys.index(paper.slug)
    black_index = family_keys.index(black.slug)

    assert paper_index < black_index, "paper family must come before black family"

    paper_volumes = products.select { |p| p.product_family_id == paper.id }.map(&:volume_in_ml)
    assert_equal paper_volumes.sort, paper_volumes
    black_volumes = products.select { |p| p.product_family_id == black.id }.map(&:volume_in_ml)
    assert_equal black_volumes.sort, black_volumes
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def make_collection(name)
    suffix = SecureRandom.hex(4)
    Collection.create!(
      name: name,
      slug: "#{name.parameterize}-#{suffix}",
      featured: true,
      sample_pack: false,
    )
  end

  def add_to_collection(collection, product)
    CollectionItem.create!(collection: collection, product: product)
  end

  def make_product_in_collection(collection, family, name, volume_in_ml)
    suffix = SecureRandom.hex(4)
    product = Product.create!(
      category: categories(:one),
      product_family: family,
      name: name,
      sku: "TC-#{suffix}",
      slug: "test-coll-#{suffix}",
      price: 10.0,
      stock_quantity: 100,
      active: true,
      product_type: "standard",
      volume_in_ml: volume_in_ml,
    )
    add_to_collection(collection, product)
    product
  end

  def make_variant_in_collection(collection, family, name, colour, material, volume_in_ml)
    suffix = SecureRandom.hex(4)
    product = Product.create!(
      category: categories(:one),
      product_family: family,
      name: name,
      colour: colour,
      material: material,
      sku: "TC-#{suffix}",
      slug: "test-coll-#{suffix}",
      price: 10.0,
      stock_quantity: 100,
      active: true,
      product_type: "standard",
      volume_in_ml: volume_in_ml,
    )
    add_to_collection(collection, product)
    product
  end

  def make_filter_product(collection, category, family, name, volume_in_ml)
    suffix = SecureRandom.hex(4)
    product = Product.create!(
      category: category,
      product_family: family,
      name: name,
      sku: "TF-#{suffix}",
      slug: "test-filter-#{suffix}",
      price: 10.0,
      stock_quantity: 100,
      active: true,
      product_type: "standard",
      volume_in_ml: volume_in_ml,
    )
    add_to_collection(collection, product)
    product
  end
end
