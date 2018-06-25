Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root to: 'home_page#show'
  resources :sessions
  get '/game', to: 'game#show'
  get '/appearance', to: 'appearance#show'
end
