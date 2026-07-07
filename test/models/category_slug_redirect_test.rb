require "test_helper"

class CategorySlugRedirectTest < ActiveSupport::TestCase
  test "renaming a category slug records a redirect from the old slug" do
    category = categories(:cups)
    old_slug = category.slug

    category.update!(slug: "renamed-for-slug-history-test")

    redirect = CategorySlugRedirect.find_by(old_slug: old_slug)
    assert_equal category, redirect&.category
  end

  test "reclaiming an old slug removes the stale redirect" do
    category = categories(:cups)
    original = category.slug

    category.update!(slug: "temporary-slug")
    category.update!(slug: original)

    assert_not CategorySlugRedirect.exists?(old_slug: original),
      "a redirect must never shadow a live slug"
    assert CategorySlugRedirect.exists?(old_slug: "temporary-slug", category_id: category.id)
  end

  test "re-renaming keeps a single redirect per old slug pointing at the owner" do
    category = categories(:cups)
    old_slug = category.slug
    category.update!(slug: "first-rename")
    category.update!(slug: "second-rename")

    assert_equal 1, CategorySlugRedirect.where(old_slug: old_slug).count
    assert CategorySlugRedirect.exists?(old_slug: "first-rename", category_id: category.id)
  end

  test "updates that do not touch the slug record nothing" do
    category = categories(:cups)

    assert_no_difference "CategorySlugRedirect.count" do
      category.update!(name: "Renamed Display Name")
    end
  end
end
