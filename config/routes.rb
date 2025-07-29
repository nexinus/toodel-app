Rails.application.routes.draw do
  get 'matches/index'
  get 'match', to: 'matches#index'
  post 'match/:id/:action_type', to: 'matches#action', as: :match_action
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
  get  '/matches/next',            to: 'matches#index', as: :next_match
  post '/matches/:id/:type',       to: 'matches#swipe', as: :swipe_match
  get '/dashboard', to: 'matches#dashboard', as: :dashboard

  
  resources :users
end
