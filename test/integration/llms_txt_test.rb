# frozen_string_literal: true

require "test_helper"

class LlmsTxtTest < ActionDispatch::IntegrationTest
  test "llms.txt is served as plain text with the site name header" do
    get "/llms.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match(/\A# Afida\n\n> /, response.body)
  end

  test "llms.txt category links use canonical nested URLs so agents never follow a redirect" do
    links = File.read(Rails.root.join("public/llms.txt")).scan(%r{https://afida\.com/categories/[^)\s]+})

    assert_operator links.size, :>, 20
    links.each do |link|
      assert_match(%r{\Ahttps://afida\.com/categories/[a-z0-9-]+/[a-z0-9-]+\z}, link, "#{link} is not a nested category URL")
    end
  end

  test "llms.txt does not link the retired cup-lids slug" do
    refute_includes File.read(Rails.root.join("public/llms.txt")), "/categories/cup-lids"
  end
end
