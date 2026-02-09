Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA routes
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Public pages
  root "pages#home"
  get "about", to: "pages#about"
  get "methodology", to: "pages#methodology"

  # Agent pages (SEO-friendly)
  resources :agents, only: [:index, :show], path: 'agents' do
    member do
      get :badge, to: 'badges#show', defaults: { format: :svg }
    end
  end
  get "compare", to: "agents#compare"

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
    end
  end

  # Admin namespace (TODO: add authentication)
  namespace :admin do
    resources :agents
    resources :evaluations, only: [:index, :show]
    root to: "agents#index"
  end
end
