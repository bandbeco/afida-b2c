require "test_helper"

class ProductFamilyTest < ActiveSupport::TestCase
  test "auto-generates slug from name on create when blank" do
    family = ProductFamily.create!(name: "Espresso Cups")
    assert_equal "espresso-cups", family.slug
  end

  test "appends numeric suffix when generated slug is taken" do
    ProductFamily.create!(name: "Espresso Cups")
    second = ProductFamily.create!(name: "Espresso Cups")
    assert_equal "espresso-cups-1", second.slug
  end

  test "keeps an explicitly provided slug" do
    family = ProductFamily.create!(name: "Espresso Cups", slug: "custom-slug")
    assert_equal "custom-slug", family.slug
  end

  test "regenerates slug from name when blanked on update" do
    family = product_families(:paper_straws)
    family.update!(name: "Bamboo Straws", slug: "")
    assert_equal "bamboo-straws", family.slug
  end

  test "does not suffix its own slug when regenerated slug is unchanged" do
    family = product_families(:single_wall_cups)
    family.update!(slug: "")
    assert_equal "single-wall-cups", family.slug
  end

  test "rejects malformed slugs" do
    [ "Hello World!", "foo/bar", "Foo", "foo_bar" ].each do |bad_slug|
      family = ProductFamily.new(name: "Test Family", slug: bad_slug)
      assert_not family.valid?, "expected #{bad_slug.inspect} to be invalid"
      assert family.errors[:slug].any?
    end
  end

  test "accepts well-formed slugs" do
    family = ProductFamily.new(name: "Test Family", slug: "foo-bar-2")
    assert family.valid?
  end

  test "requires a name" do
    family = ProductFamily.new(slug: "some-slug")
    assert_not family.valid?
    assert family.errors[:name].any?
  end

  test "requires a unique slug" do
    family = ProductFamily.new(name: "Duplicate", slug: product_families(:single_wall_cups).slug)
    assert_not family.valid?
    assert family.errors[:slug].any?
  end
end
