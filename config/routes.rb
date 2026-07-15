Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"

  get "i/:slug", to: "respondents#show", as: :respondent # routes of external users so they don't need to authenticate when they click on the link
  get "i/:slug/signed_url", to: "respondents#signed_url", as: :respondent_signed_url

  resources :loops do
    member do
      post :activate
      post :deactivate
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "dashboard", to: "dashboard#index", as: :dashboard
  patch "dashboard/stat_preferences", to: "dashboard#update_stat_preferences", as: :dashboard_stat_preferences

  get "analyse", to: "analyse#index", as: :analyse_index
  get "analyse/:slug", to: "analyse#show", as: :analyse

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
