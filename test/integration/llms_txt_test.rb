# frozen_string_literal: true

require "test_helper"
require "csv"

class LlmsTxtTest < ActionDispatch::IntegrationTest
  CATEGORIES_CSV = Rails.root.join("lib/data/categories.csv")

  test "llms.txt is served as plain text with the site name header" do
    get "/llms.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match(/\A# Afida\n\n> /, response.body)
  end

  test "llms.txt category links match LIVE_TAXONOMY and sit under that parent heading" do
    text = File.read(Rails.root.join("public/llms.txt"))
    names_by_slug = CSV.read(CATEGORIES_CSV, headers: true).to_h { |row| [ row["slug"], row["name"] ] }

    heading = nil
    seen = []
    text.each_line do |line|
      heading = line.delete_prefix("### ").strip if line.start_with?("### ")
      line.scan(%r{\[([^\]]+)\]\(https://afida\.com/categories/([a-z0-9-]+)/([a-z0-9-]+)\)}).each do |label, parent, child|
        seen << [ label, parent, child, heading ]
      end
    end

    assert_operator seen.size, :>, 20
    seen.each do |label, parent, child, section|
      children = LiveTaxonomy::TREE[parent]
      assert children, "#{parent} is not a live parent category"
      assert_includes children, child, "#{child} is not a child of #{parent}"
      assert_equal names_by_slug[parent], section,
        "#{child} is under #{section.inspect}, expected #{names_by_slug[parent].inspect}"
      assert_equal normalize_category_name(names_by_slug[child]), normalize_category_name(label),
        "#{child} is labelled #{label.inspect}, expected #{names_by_slug[child].inspect}"
    end
  end

  test "llms.txt does not link the retired cup-lids slug" do
    refute_includes File.read(Rails.root.join("public/llms.txt")), "/categories/cup-lids"
  end

  private

  def normalize_category_name(name)
    name.to_s.downcase.gsub(/[&+]/, "").gsub(/\s+/, " ").strip
  end
end
