# frozen_string_literal: true
Rails.application.routes.draw do
  # Authentication
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Health check
  get "up" => "rails/health#show", :as => :rails_health_check

  # PWA routes
  get "service-worker" => "rails/pwa#service_worker", :as => :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", :as => :pwa_manifest

  # Public pages
  root "pages#home"
  get "about", to: "pages#about"
  get "methodology", to: "pages#methodology"
  get "badges", to: "pages#badges"

  # Agent pages (SEO-friendly)
  resources :agents, only: [:index, :show], path: "agents" do
    member do
      get :badge, to: "badges#show", defaults: { format: :svg }
    end

    # Agent profiles and claiming
    resource :profile, only: [:show], controller: "agents/profiles"
    resource :claim, only: [:create], controller: "agents/claims" do
      post :verify, on: :member
    end
  end
  get "compare", to: "agents#compare"

  # Builder dashboard
  namespace :builder do
    root to: "dashboard#index"
    resources :agents, only: [:edit, :update] do
      resource :notification_preferences, only: [:edit, :update]
    end
  end

  # Public badge endpoint (for README embeds)
  get "badge/:agent_name", to: "badges#show", as: :agent_badge

  # API v1
  namespace :api do
    namespace :v1 do
      resources :agents, only: [:index, :show] do
        member do
          get :score
        end
        collection do
          get :compare
          get :search
        end
      end
      resources :telemetry, only: [:create]
      resources :certifications, only: [:show, :create]

      # Standalone comparison and search endpoints
      resources :compare, only: [:index]
      resources :search, only: [:index]

      # CI/CD deploy gate
      resources :deploy_gates, only: [] do
        collection do
          post :check
        end
      end

      # Agent claiming
      resources :claims, only: [:create] do
        member do
          post :verify
        end
      end

      # MCP (Model Context Protocol) endpoint
      post "mcp", to: "mcp#handle"
    end
  end

  # Admin namespace with authentication
  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [:index, :show, :edit, :update, :destroy]
    resources :agents, only: [:index, :show, :edit, :update, :destroy] do
      member do
        post :run_tier0
        post :run_tier1
        post :run_tier2
        get :evals, to: "evaluations#agent_evals"
      end
    end
    resources :api_keys, only: [:index, :destroy]

    resources :pending_agents, only: [:index, :show] do
      member do
        post :approve
        post :reject
      end
    end

    # Evaluation observability
    resources :evaluations, only: [:index, :show] do
      collection do
        get :tasks
        get "tasks/:id", action: :task, as: :task
        post :run_all_tier1
      end
    end
  end
end
