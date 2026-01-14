Rails.application.routes.draw do
  # =============================================================================
  # WWW to non-WWW redirect (301 Permanent)
  # Ensures all traffic uses canonical afida.com domain for SEO
  # =============================================================================
  constraints(host: /^www\./i) do
    get "(*path)", to: redirect(status: 301) { |params, req|
      "https://afida.com/#{params[:path]}#{req.query_string.present? ? "?#{req.query_string}" : ""}"
    }, format: false
  end

  root "pages#home"

  # =============================================================================
  # Legacy URL Redirects (301 Permanent)
  # From old Wix site (afida.com) - preserves SEO and backlinks
  # =============================================================================

  # Legacy category redirects (preserves query params for UTM tracking)
  get "/category/cold-cups-lids", to: redirect(status: 301) { |_params, req| "/categories/cups-and-lids#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/hot-cups", to: redirect(status: 301) { |_params, req| "/categories/cups-and-lids#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/hot-cup-extras", to: redirect(status: 301) { |_params, req| "/categories/cups-and-lids#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/napkins", to: redirect(status: 301) { |_params, req| "/categories/napkins#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/pizza-boxes", to: redirect(status: 301) { |_params, req| "/categories/pizza-boxes#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/straws", to: redirect(status: 301) { |_params, req| "/categories/straws#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/takeaway-containers", to: redirect(status: 301) { |_params, req| "/categories/takeaway-containers#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/takeaway-extras", to: redirect(status: 301) { |_params, req| "/categories/takeaway-extras#{req.query_string.present? ? "?#{req.query_string}" : ""}" }
  get "/category/all-products", to: redirect(status: 301) { |_params, req| "/shop#{req.query_string.present? ? "?#{req.query_string}" : ""}" }

  # Legacy page redirects (preserves query params for UTM tracking)
  get "/branded-packaging", to: redirect(status: 301) { |_params, req| "/branding#{req.query_string.present? ? "?#{req.query_string}" : ""}" }

  get "shop", to: "pages#shop"
  get "search", to: "search#index"
  get "branding", to: "pages#branding"
  resources :samples, only: [ :index ] do
    collection do
      get ":category_slug", action: :category, as: :category
    end
  end
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

  # B2B Price List
  get "price-list", to: "price_list#index", as: :price_list
  get "price-list/export", to: "price_list#export", as: :price_list_export

  resources :products, only: [ :index, :show ], param: :slug do
    member do
      get :quick_add
    end
  end
  resources :categories, only: [ :show ]
  resources :branded_products, only: [ :index, :show ], path: "branded-products", param: :slug

  resource :session, path: "signin", path_names: { new: "" }
  resources :passwords, param: :token
  resource :registration, only: [ :new, :create ], path: "signup", path_names: { new: "" }

  resources :email_address_verifications, only: [ :show, :create ], param: :token

  resource :cart, only: [ :show, :destroy ] do
    resources :cart_items, only: [ :create, :update, :destroy ], path_names: { edit: "" }
  end

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

  # Stripe webhooks
  namespace :webhooks do
    post :stripe, to: "stripe#create"
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
      end
      member do
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
    resources :orders, only: [ :index, :show ]
    resources :blog_posts
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
