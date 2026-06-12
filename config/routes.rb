OpenehrRails::Engine.routes.draw do
  root to: 'templates#index'

  resources :templates, only: %i[index create destroy] do
    member do
      post :generate
    end
  end
end
