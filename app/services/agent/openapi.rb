# frozen_string_literal: true

module Agent
  class Openapi
    def initialize(base_url:)
      @base_url = base_url.to_s.delete_suffix("/")
    end

    def document
      {
        "openapi" => "3.1.0",
        "info" => {
          "title" => "Afida Catalog API",
          "version" => "1.0.0",
          "description" => "Public catalog for Afida eco-packaging. Prices are GBP excl. VAT. Checkout is Stripe-hosted."
        },
        "x-service-info" => {
          "name" => "Afida",
          "categories" => [ "ecommerce", "packaging" ]
        },
        "servers" => [ { "url" => @base_url } ],
        "paths" => {
          "/api/v1/products" => {
            "get" => {
              "operationId" => "listProducts",
              "summary" => "List or search catalog products",
              "security" => [],
              "parameters" => [
                { "name" => "q", "in" => "query", "schema" => { "type" => "string" } },
                { "name" => "category", "in" => "query", "schema" => { "type" => "string" } },
                { "name" => "page", "in" => "query", "schema" => { "type" => "integer" } },
                { "name" => "per_page", "in" => "query", "schema" => { "type" => "integer" } }
              ],
              "responses" => { "200" => { "description" => "Product list" } }
            }
          },
          "/api/v1/products/{slug}" => {
            "get" => {
              "operationId" => "getProduct",
              "summary" => "Get a product by slug",
              "security" => [],
              "parameters" => [
                { "name" => "slug", "in" => "path", "required" => true, "schema" => { "type" => "string" } }
              ],
              "responses" => {
                "200" => { "description" => "Product" },
                "404" => { "description" => "Not found" }
              }
            }
          },
          "/api/v1/categories" => {
            "get" => {
              "operationId" => "listCategories",
              "summary" => "List categories",
              "security" => [],
              "responses" => { "200" => { "description" => "Category list" } }
            }
          },
          "/api/v1/categories/{slug}" => {
            "get" => {
              "operationId" => "getCategory",
              "summary" => "Get a category by slug",
              "security" => [],
              "parameters" => [
                { "name" => "slug", "in" => "path", "required" => true, "schema" => { "type" => "string" } }
              ],
              "responses" => { "200" => { "description" => "Category" } }
            }
          },
          "/api/v1/acp/checkout_sessions" => {
            "post" => {
              "operationId" => "createCheckoutSession",
              "summary" => "Create a Stripe Checkout session for catalog line items",
              "x-payment-info" => {
                "intent" => "session",
                "method" => "stripe",
                "amount" => "100.00",
                "currency" => "GBP",
                "description" => "Hosted Stripe Checkout; the charged amount is the cart total. Free UK delivery over £100 excl. VAT."
              },
              "requestBody" => {
                "required" => true,
                "content" => {
                  "application/json" => {
                    "schema" => {
                      "type" => "object",
                      "required" => [ "items" ],
                      "properties" => {
                        "items" => {
                          "type" => "array",
                          "items" => {
                            "type" => "object",
                            "required" => [ "slug", "quantity" ],
                            "properties" => {
                              "slug" => { "type" => "string" },
                              "quantity" => { "type" => "integer", "minimum" => 1 }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              },
              "responses" => {
                "201" => { "description" => "Checkout session with Stripe-hosted checkout_url" },
                "422" => { "description" => "Invalid items" }
              }
            }
          }
        }
      }
    end
  end
end
