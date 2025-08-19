Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: 'users/registrations' }
  get "welcome/index"
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root to: 'welcome#index'
  
  # Matches and team invitations routes
  resources :matches, only: [:index, :show, :create] do
    member do
      get :chat
      get :team_chat
      post :accept
      post :decline
      post :invite
      post :skip
    end
  end
  
  # Teams routes
  resources :teams, except: [:destroy] do
    member do
      post :join
      post :leave
      post :add_member
      post :remove_member
      get :chat
    end
  end
  
  # Dashboard and discovery routes
  get "/dashboard", to: "matches#dashboard", as: :dashboard
  get "/discover", to: "matches#discover", as: :discover
  
  # User profile and onboarding
  resources :users, only: [:index, :show, :edit, :update] do
    member do
      get :profile
      get :onboarding
      patch :complete_onboarding
    end
  end
  
  # ActionCable for real-time features
  mount ActionCable.server => '/cable'
end
