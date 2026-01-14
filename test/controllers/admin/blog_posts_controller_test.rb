# frozen_string_literal: true

require "test_helper"

class Admin::BlogPostsControllerTest < ActionDispatch::IntegrationTest
  # ==========================================================================
  # Setup
  # ==========================================================================

  setup do
    @headers = { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" }
    @admin = users(:acme_admin)
    @published_post = blog_posts(:published_post)
    @draft_post = blog_posts(:draft_post)

    # Set host to avoid www redirect in routes
    host! "example.com"
    sign_in_as(@admin)
  end

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }, headers: @headers
  end

  # ==========================================================================
  # Authentication
  # ==========================================================================

  test "index requires admin authentication" do
    delete session_url, headers: @headers
    get admin_blog_posts_url, headers: @headers
    # Unauthenticated users are redirected to sign in
    assert_redirected_to new_session_path
  end

  test "new requires admin authentication" do
    delete session_url, headers: @headers
    get new_admin_blog_post_url, headers: @headers
    assert_redirected_to new_session_path
  end

  test "create requires admin authentication" do
    delete session_url, headers: @headers
    post admin_blog_posts_url, params: { blog_post: { title: "Test" } }, headers: @headers
    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Index Action
  # ==========================================================================

  test "index shows all posts including drafts" do
    get admin_blog_posts_url, headers: @headers

    assert_response :success
    assert_includes response.body, @published_post.title
    assert_includes response.body, @draft_post.title
  end

  test "index shows post status badges" do
    get admin_blog_posts_url, headers: @headers

    assert_response :success
    # Should have badges distinguishing published and draft states
    assert_match(/published|draft/i, response.body)
  end

  # ==========================================================================
  # New Action
  # ==========================================================================

  test "new renders form" do
    get new_admin_blog_post_url, headers: @headers

    assert_response :success
    assert_select "form"
    assert_select "input[name='blog_post[title]']"
    assert_select "textarea[name='blog_post[body]']"
  end

  test "new form has SEO fields" do
    get new_admin_blog_post_url, headers: @headers

    assert_response :success
    assert_select "input[name='blog_post[meta_title]']"
    assert_select "textarea[name='blog_post[meta_description]']"
  end

  test "new form has publish checkbox" do
    get new_admin_blog_post_url, headers: @headers

    assert_response :success
    assert_select "input[type=checkbox][name='blog_post[published]']"
  end

  # ==========================================================================
  # Create Action
  # ==========================================================================

  test "create saves valid blog post" do
    assert_difference("BlogPost.count", 1) do
      post admin_blog_posts_url, params: {
        blog_post: {
          title: "New Test Post",
          body: "This is the body content.",
          published: false
        }
      }, headers: @headers
    end

    assert_redirected_to admin_blog_posts_url
    assert_equal "New Test Post", BlogPost.last.title
  end

  test "create generates slug automatically" do
    post admin_blog_posts_url, params: {
      blog_post: {
        title: "Auto Slug Test Post",
        body: "Body content here."
      }
    }, headers: @headers

    assert_equal "auto-slug-test-post", BlogPost.last.slug
  end

  test "create allows custom slug" do
    post admin_blog_posts_url, params: {
      blog_post: {
        title: "Custom Slug Post",
        slug: "my-custom-slug",
        body: "Body content."
      }
    }, headers: @headers

    assert_equal "my-custom-slug", BlogPost.last.slug
  end

  test "create with invalid data re-renders form" do
    assert_no_difference("BlogPost.count") do
      post admin_blog_posts_url, params: {
        blog_post: {
          title: "",
          body: ""
        }
      }, headers: @headers
    end

    assert_response :unprocessable_entity
  end

  test "create with SEO fields saves them" do
    post admin_blog_posts_url, params: {
      blog_post: {
        title: "SEO Test Post",
        body: "Body content.",
        meta_title: "Custom SEO Title",
        meta_description: "Custom meta description for search engines."
      }
    }, headers: @headers

    post = BlogPost.last
    assert_equal "Custom SEO Title", post.meta_title
    assert_equal "Custom meta description for search engines.", post.meta_description
  end

  test "create with published true sets published_at" do
    post admin_blog_posts_url, params: {
      blog_post: {
        title: "Published Post",
        body: "Body content.",
        published: true
      }
    }, headers: @headers

    post = BlogPost.last
    assert post.published?
    assert_not_nil post.published_at
  end

  # ==========================================================================
  # Edit Action
  # ==========================================================================

  test "edit renders form with existing data" do
    get edit_admin_blog_post_url(id: @published_post.id), headers: @headers

    assert_response :success
    assert_select "form"
    assert_select "input[name='blog_post[title]'][value=?]", @published_post.title
  end

  test "edit requires admin authentication" do
    delete session_url, headers: @headers
    get edit_admin_blog_post_url(id: @published_post.id), headers: @headers
    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Update Action
  # ==========================================================================

  test "update saves changes" do
    patch admin_blog_post_url(id: @draft_post.id), params: {
      blog_post: { title: "Updated Title" }
    }, headers: @headers

    assert_redirected_to admin_blog_posts_url
    @draft_post.reload
    assert_equal "Updated Title", @draft_post.title
  end

  test "update can change slug" do
    patch admin_blog_post_url(id: @draft_post.id), params: {
      blog_post: { slug: "new-custom-slug" }
    }, headers: @headers

    @draft_post.reload
    assert_equal "new-custom-slug", @draft_post.slug
  end

  test "update with invalid data re-renders form" do
    patch admin_blog_post_url(id: @draft_post.id), params: {
      blog_post: { title: "" }
    }, headers: @headers

    assert_response :unprocessable_entity
  end

  test "update can publish a draft" do
    assert_not @draft_post.published?
    assert_nil @draft_post.published_at

    patch admin_blog_post_url(id: @draft_post.id), params: {
      blog_post: { published: true }
    }, headers: @headers

    @draft_post.reload
    assert @draft_post.published?
    assert_not_nil @draft_post.published_at
  end

  test "update requires admin authentication" do
    delete session_url, headers: @headers
    patch admin_blog_post_url(id: @draft_post.id), params: {
      blog_post: { title: "Hacked" }
    }, headers: @headers
    assert_redirected_to new_session_path
  end

  # ==========================================================================
  # Destroy Action
  # ==========================================================================

  test "destroy deletes the post" do
    assert_difference("BlogPost.count", -1) do
      delete admin_blog_post_url(id: @draft_post.id), headers: @headers
    end

    assert_redirected_to admin_blog_posts_url
  end

  test "destroy requires admin authentication" do
    delete session_url, headers: @headers
    assert_no_difference("BlogPost.count") do
      delete admin_blog_post_url(id: @draft_post.id), headers: @headers
    end
    assert_redirected_to new_session_path
  end
end
