Rails.application.routes.draw do
  get 'bmi',to: "bmi#index"
  post 'bmi/result',to: "bmi#result"
  devise_for :users
  resources :keyword_mappings
  resources :push_messages, only: [:new, :create]
  resources :rent_stuff
  resources :candidates do
    member do
      post :vote
    end
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get '/', to: 'kamigoo#eat'
  get '/kamigoo/eat', to: 'kamigoo#eat'
  get '/kamigoo/request_headers', to: 'kamigoo#request_headers'
  get '/kamigoo/request_body', to: 'kamigoo#request_body'
  get '/kamigoo/response_headers', to: 'kamigoo#response_headers'
  get '/kamigoo/response_body', to: 'kamigoo#show_response_body'
  
  get '/kamigoo/sent_request', to: 'kamigoo#sent_request'
  get '/kamigoo/sent_request1', to: 'kamigoo#sent_request1'
  
  post '/kamigoo/webhook', to: 'kamigoo#webhook'
end
