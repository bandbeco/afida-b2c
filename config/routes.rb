Rails.application.routes.draw do
  # =============================================================================
  # WWW to non-WWW redirect (301 Permanent)
  # Ensures all traffic uses canonical afida.com domain for SEO
  # Only matches www.afida.com to avoid interfering with test hosts
  # =============================================================================
  constraints(host: "www.afida.com") do
    get "(*path)", to: redirect(status: 301) { |params, req|
      "https://afida.com/#{params[:path]}#{req.query_string.present? ? "?#{req.query_string}" : ""}"
    }, format: false
  end

  root "pages#home"

  # =============================================================================
  # Legacy URL Redirects (301 Permanent)
  # From old Wix site (afida.com) - preserves SEO and backlinks
  # =============================================================================

  # Legacy category redirects — chained through to final new URLs
  get "/category/cold-cups-lids", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/hot-cups", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/hot-cup-extras", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/napkins", to: redirect(status: 301) { |_params, req| "/categories/tableware/napkins#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/pizza-boxes", to: redirect(status: 301) { |_params, req| "/categories/food-containers/pizza-boxes#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/straws", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories/straws#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/takeaway-containers", to: redirect(status: 301) { |_params, req| "/categories/food-containers#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/takeaway-extras", to: redirect(status: 301) { |_params, req| "/categories/supplies-and-essentials#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/all-products", to: redirect(status: 301) { |_params, req| "/shop#{req.query_string.present? ? "?#{req.query_string}" : ""}" }

  # Catch-all for unknown /category/* paths (prevents URI::InvalidURIError from www redirect)
  # Must come after specific category redirects above
  get "/category/*path", to: redirect(status: 301) { "/shop" }

  # Legacy page redirects (preserves query params for UTM tracking)
  get "/branded-packaging", to: redirect(status: 301) { |_params, req| "/branding#{req.query_string.present? ? "?#{req.query_string}" : ""}" }

  # Legacy Wix homepage / orphan page aliases (Google Search Console drilldown 2026-05-10)
  get "/index.php", to: redirect(status: 301, path: "/")
  get "/home", to: redirect(status: 301, path: "/")
  get "/blank-3", to: redirect(status: 301, path: "/")

  # Legacy Wix /collections/* (only the one URL we've seen 404 in GSC)
  get "/collections/paper-straws", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories/straws#{req.query_string.present? ? "?#{req.query_string}" : ""}" }

  # Legacy Wix /product-page/* — map known SKUs to current product slugs
  get "/product-page/12oz-340ml-double-wall-ripple-paper-hot-cup", to: redirect(status: 301) { |_params, req| "/products/ripple-wall-coffee-cups-12oz-340ml-kraft-paper#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/product-page/8oz-227ml-double-wall-ripple-paper-hot-cup-black", to: redirect(status: 301) { |_params, req| "/products/ripple-wall-coffee-cups-8oz-227ml-black-paper#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/product-page/6mm-x-200mm-bamboo-fibre-straws-black", to: redirect(status: 301) { |_params, req| "/products/straws-6-x-200mm-bamboo-pulp#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/product-page/6mm-x-200mm-bamboo-fibre-straws-natural", to: redirect(status: 301) { |_params, req| "/products/straws-6-x-200mm-bamboo-pulp#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/product-page/4-fold-white-2ply-dinner-napkins-40cm-x-40cm", to: redirect(status: 301) { |_params, req| "/products/4-fold-2-ply-dinner-napkins-40-x-40cm-white-paper#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/product-page/no-3-kraft-deli-box-70oz", to: redirect(status: 301) { |_params, req| "/products/takeaway-boxes-no-3-1900ml-69oz-kraft#{req.query_string.present? ? "?#{req.query_string}" : ""}" }

  # Catch-all for unmapped /product-page/* paths — fall back to /shop
  # Must come after the specific product-page redirects above
  get "/product-page/*path", to: redirect(status: 301) { "/shop" }

  get "shop", to: "pages#shop"
  get "search", to: "search#index"
  get "branding", to: "pages#branding"
  resources :samples, only: [ :index ] do
    collection do
      get "category/:category_slug", action: :category, as: :category
    end
  end

  # Fixed sample packs for PPC/email landing pages
  resources :sample_packs, only: [ :show ], path: "sample-packs", param: :slug do
    member do
      post :request_pack
    end
  end
  get "vegware", to: "pages#vegware"
  get "about", to: "pages#about"
  get "contact", to: "pages#contact"
  get "terms-conditions", to: "pages#terms_conditions"
  get "privacy-policy", to: "pages#privacy_policy"
  get "cookies-policy", to: "pages#cookies_policy"
  get "accessibility-statement", to: "pages#accessibility_statement"
  get "return-policy", to: "pages#return_policy"
  get "delivery-returns", to: "pages#delivery_returns"
  get "pattern-demo", to: "pages#pattern_demo" if Rails.env.development?
  get "sentry-test", to: "pages#sentry_test" if Rails.env.development?

  # FAQ page
  get "faqs", to: "faqs#index"

  # Blog
  resources :blog_posts, only: [ :index, :show ], path: "blog", param: :slug
  get "blog/categories/:slug", to: "blog_categories#show", as: :blog_category

  # B2B Price List
  get "price-list", to: "price_list#index", as: :price_list
  get "price-list/export", to: "price_list#export", as: :price_list_export

  resources :products, only: [ :index, :show ], param: :slug do
    member do
      get :quick_add
    end
  end
  # Category routes — old flat slugs redirect 301 to new URLs (PRD Section 8)
  # NOTE: /categories/food-containers is intentionally NOT redirected — it is the
  # current slug of a real top-level category (formerly "hot-food"), so it must
  # render directly. A redirect here would shadow the live category page.
  get "/categories/cups-and-lids", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/ice-cream-cups", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories/ice-cream-cups#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/napkins", to: redirect(status: 301) { |_params, req| "/categories/tableware/napkins#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/pizza-boxes", to: redirect(status: 301) { |_params, req| "/categories/food-containers/pizza-boxes#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/straws", to: redirect(status: 301) { |_params, req| "/categories/cups-and-accessories/straws#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/takeaway-containers", to: redirect(status: 301) { |_params, req| "/categories/food-containers#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/takeaway-extras", to: redirect(status: 301) { |_params, req| "/categories/supplies-and-essentials#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/plates-trays", to: redirect(status: 301) { |_params, req| "/categories/tableware/plates-and-bowls#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/bagasse-eco-range", to: redirect(status: 301) { |_params, req| "/categories/food-containers/bagasse-containers#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/takeaway-boxes", to: redirect(status: 301) { |_params, req| "/categories/food-containers/takeaway-boxes#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/cutlery", to: redirect(status: 301) { |_params, req| "/categories/tableware/cutlery#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/categories/bags", to: redirect(status: 301) { |_params, req| "/categories/bags-and-wraps/bags#{req.query_string.present? ? "?#{req.query_string}" : ""}" }

  # Nested subcategory route: /categories/:parent_slug/:id
  get "/categories/:parent_slug/:id", to: "categories#show", as: :category_subcategory

  # Parent/top-level category route: /categories/:id
  resources :categories, only: [ :show ]
  resources :collections, only: [ :index, :show ], param: :slug do
    get ":category_slug", action: :category_filter, on: :member, as: :category_filter
  end
  resources :branded_products, only: [ :index, :show ], path: "branded-products", param: :slug

  resource :session, path: "signin", path_names: { new: "" }
  resources :passwords, param: :token
  resource :registration, only: [ :new, :create ], path: "signup", path_names: { new: "" }

  resources :email_address_verifications, only: [ :show, :create ], param: :token

  resource :cart, only: [ :show, :destroy ] do
    get :resume # GET /cart/resume?token=... — restore an abandoned cart from a recovery link
    resources :cart_items, only: [ :create, :update, :destroy ], path_names: { edit: "" }
  end

  resources :email_subscriptions, only: [ :create ]

  resource :checkout, only: [ :show, :create ] do
    get :success, on: :collection
    get :cancel, on: :collection
  end

  resources :orders, only: [ :show, :index ] do
    member do
      get :confirmation
      post :reorder
    end
  end

  # Account management
  resource :account, only: [ :show, :update ]

  # Account sub-resources (addresses, etc.)
  namespace :account do
    resources :addresses, except: [ :show ] do
      member do
        patch :set_default
      end
      collection do
        post :create_from_order
      end
    end
  end

  # Post-checkout guest-to-account conversion
  resource :post_checkout_registration, only: [ :create ]

  # Reorder Schedules
  resources :reorder_schedules, path: "reorder-schedules" do
    member do
      patch :pause
      patch :resume
      patch :skip_next
    end
    collection do
      get :setup           # Start setup flow (from order)
      get :setup_success   # Stripe redirect after payment method saved
      get :setup_cancel    # Stripe redirect on cancel
    end
  end

  resources :pending_orders, path: "pending-orders", only: [ :show, :edit, :update ] do
    member do
      post :confirm                       # Confirmation after reviewing order
      post :update_payment_method         # Redirect to Stripe to update card
      get :update_payment_method_success  # Callback after Stripe updates card
    end
  end

  # Internal API
  namespace :api, defaults: { format: :json } do
    namespace :internal do
      namespace :v1 do
        resources :blog_posts, only: [ :create, :show, :index, :update ], param: :id_or_slug
      end
    end
  end

  # Webhooks (Stripe, Outrank, etc.)
  namespace :webhooks do
    post :stripe, to: "stripe#create"
    post :outrank, to: "outrank#create"
  end

  namespace :branded_products do
    post "calculate_price", to: "configurator#calculate_price"
    get "available_options/:product_id", to: "configurator#available_options", as: :available_options
    get "compatible_lids", to: "lids#compatible_lids"
  end

  namespace :organizations do
    resources :products, only: [ :index, :show ]
  end

  namespace :admin do
    get "/", to: "products#index"
    resources :products do
      collection do
        get :order
        post :preview_title
      end
      member do
        patch :update_category
        patch :update_family
        patch :toggle_boolean
        patch :move_higher
        patch :move_lower
        delete :product_photo, to: "products#destroy_product_photo"
        delete :lifestyle_photo, to: "products#destroy_lifestyle_photo"
        post :add_compatible_lid
        delete :remove_compatible_lid
        patch :set_default_compatible_lid
        patch :update_compatible_lids
      end
    end
    resources :categories do
      collection do
        get :order
      end
      member do
        patch :move_higher
        patch :move_lower
      end
    end
    resources :collections do
      collection do
        get :order
      end
      member do
        patch :move_higher
        patch :move_lower
      end
    end
    resources :orders, only: [ :index, :show ]

    # Blog management at /admin/blog/posts and /admin/blog/categories
    scope :blog do
      resources :posts, controller: "blog_posts", as: :blog_posts
      resources :categories, controller: "blog_categories", except: [ :show ], as: :blog_categories
    end
    resource :settings, only: [ :show, :update ] do
      delete :hero_image, on: :collection, action: :destroy_hero_image
      post :branding_images, on: :collection, action: :add_branding_image
      delete "branding_images/:id", on: :collection, action: :remove_branding_image, as: :remove_branding_image
      patch "branding_images/:id/move_higher", on: :collection, action: :move_branding_image_higher, as: :move_branding_image_higher
      patch "branding_images/:id/move_lower", on: :collection, action: :move_branding_image_lower, as: :move_branding_image_lower
      patch "branding_images/:id", on: :collection, action: :update_branding_image, as: :update_branding_image
    end
    resources :branded_orders, path: "branded-orders", only: [ :index, :show ] do
      member do
        patch :update_status
        post :create_instance_product
      end
    end
  end

  # Product feeds
  get "feeds/google-merchant.xml", to: "feeds#google_merchant", as: :google_merchant_feed
  get "sitemap.xml", to: "sitemaps#show", defaults: { format: :xml }, as: :sitemap
  get "robots.txt", to: "robots#show", defaults: { format: :text }

  get "up" => "rails/health#show", as: :rails_health_check
end
