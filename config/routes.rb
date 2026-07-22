Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations", confirmations: "users/confirmations" }
  root to: "pages#home"

  get "check-email", to: "check_email#show", as: :check_email

  get "i/:slug", to: "respondents#show", as: :respondent # routes of external users so they don't need to authenticate when they click on the link
  get "i/:slug/signed_url", to: "respondents#signed_url", as: :respondent_signed_url

  # ElevenLabs posts finished conversations here. Registered workspace-wide in their
  # dashboard, so every agent's transcripts arrive on this one endpoint.
  post "webhooks/elevenlabs", to: "eleven_labs_webhooks#create", as: :eleven_labs_webhook

  resources :loops do
    member do
      post :activate
      post :deactivate
      post :approve
    end
  end

  resources :question_library_entries, path: "question-library", except: %i[new show] do
    member do
      post :use
    end
  end
  resources :question_library_categories, path: "question-library/categories", only: %i[create edit update destroy]

  get "team", to: "team#index", as: :team
  post "team", to: "team#create"
  patch "team/:id", to: "team#update", as: :team_member
  delete "team/:id", to: "team#destroy"

  patch "workspace", to: "workspace#update", as: :workspace
  delete "workspace", to: "workspace#destroy"

  get "invitations/:invitation_token", to: "invitations#show", as: :invitation
  patch "invitations/:invitation_token", to: "invitations#update"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "dashboard", to: "dashboard#index", as: :dashboard
  patch "dashboard/stat_preferences", to: "dashboard#update_stat_preferences", as: :dashboard_stat_preferences

  get "deploy", to: "deploy#index", as: :deploy
  post "deploy/:loop_id/invites", to: "deploy#send_invites", as: :deploy_invites

  get "analyze", to: "analyze#index", as: :analyze_index
  get "analyze/:slug", to: "analyze#show", as: :analyze
  post "analyze/:slug/refresh", to: "analyze#refresh", as: :refresh_analyze
  post "analyze/:slug/backfill", to: "analyze#backfill", as: :backfill_analyze

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
