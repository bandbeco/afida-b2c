require "test_helper"

# The attach block turns the compatibility mapping into one selection inside the
# main buy form: tick what you need, submit once. Both directions share the row
# anatomy - containers offer lids, lids offer the containers they fit.
class ProductAttachBlockTest < ActionDispatch::IntegrationTest
  setup do
    @container = products(:branded_cup_8oz)
    @lid = products(:flat_lid_8oz)
  end

  test "a container page offers its compatible lids as checkboxes in the add-to-cart form" do
    get product_path(@container)

    assert_select "form#add-to-cart-form [data-test='attach-row']" do
      assert_select "input[type=checkbox][name=\"companions[0][sku]\"]"
    end
  end

  test "each attach row names the companion and its per-unit rate" do
    get product_path(@container)

    assert_select "[data-test='attach-row']" do |rows|
      row = rows.first
      assert_match @lid.generated_title, row.text
      assert_match(/1\.5p \/ unit/, row.text)
    end
  end

  # The lid carries its own sizing vocabulary ("500ml / 1000ml" on a 650ml tray
  # page), which reads as a mismatch. The fit cue is what removes that doubt.
  test "attach rows on a container page state that the lid fits this container" do
    get product_path(@container)

    assert_select "[data-test='attach-row']", text: /fits this/i
  end

  test "no attach row is pre-ticked" do
    get product_path(@container)

    assert_select "[data-test='attach-row'] input[type=checkbox][checked]", count: 0
  end

  test "the default lid sorts first and is cued as the popular choice" do
    get product_path(@container)

    assert_select "[data-test='attach-row']" do |rows|
      assert_match @lid.generated_title, rows.first.text
      assert_match(/most popular/i, rows.first.text)
    end
  end

  # Curation names one default lid. If that lid is deactivated the cue has to
  # move to a lid the buyer can actually order, not vanish with it.
  test "the popular cue moves to an active lid when the default is deactivated" do
    @lid.update!(active: false)

    get product_path(@container)

    assert_select "[data-test='attach-popular-cue']", count: 1
    assert_select "[data-test='attach-row']" do |rows|
      assert_match(/most popular/i, rows.first.text)
    end
  end

  test "a container page shows at most four lids and no disclosure" do
    5.times do |i|
      lid = Product.create!(category: @lid.category, name: "Extra Lid #{i}",
                            sku: "LID-EXTRA-#{i}", price: 10, pac_size: 1000,
                            stock_quantity: 10, active: true)
      ProductCompatibleLid.create!(product: @container, compatible_lid: lid, sort_order: 10 + i)
    end

    get product_path(@container)

    assert_select "[data-test='attach-row']", count: 4
    assert_select "[data-test='attach-disclosure']", count: 0
  end

  test "a lid page offers the containers it fits" do
    get product_path(@lid)

    assert_select "form#add-to-cart-form [data-test='attach-row']" do
      assert_select "input[type=checkbox][name=\"companions[0][sku]\"]"
    end
    assert_select "[data-test='attach-row']", text: /#{@container.generated_title}/
  end

  # Fit-checking buyers may need the container's own dimensions, so the row
  # links out. Container pages do not link their lids: navigating away from a
  # lid you can attach right here is pure downside.
  test "container names on a lid page link to their product pages" do
    get product_path(@lid)

    assert_select "[data-test='attach-row'] a[href=?]", product_path(@container)
  end

  test "lid names on a container page do not link away" do
    get product_path(@container)

    assert_select "[data-test='attach-row'] a[href=?]", product_path(@lid), count: 0
  end

  test "a lid page beyond four containers keeps the rest behind a disclosure" do
    6.times do |i|
      container = Product.create!(category: @container.category, name: "Extra Tray #{i}",
                                  sku: "TRAY-EXTRA-#{i}", price: 20, pac_size: 500,
                                  stock_quantity: 10, active: true)
      ProductCompatibleLid.create!(product: container, compatible_lid: @lid, sort_order: 1)
    end

    get product_path(@lid)

    assert_select "[data-test='attach-row']", count: 7
    assert_select "[data-test='attach-disclosure']", text: /show all 7/i
  end

  test "a product with no mappings in either direction renders no attach block" do
    get product_path(products(:napkin_small_white))

    assert_select "[data-test='attach-row']", count: 0
    assert_select "[data-test='attach-block']", count: 0
  end

  test "inactive companions are not offered" do
    @lid.update!(active: false)

    get product_path(@container)

    assert_select "[data-test='attach-row']", text: /#{@lid.generated_title}/, count: 0
  end
end
