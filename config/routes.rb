OpenehrRails::Engine.routes.draw do
  root to: 'templates#index'

  resources :templates, only: %i[index create destroy] do
    member do
      post :generate
    end
  end

  # HL7 FHIR R5 facade (base URL: <mount-point>/fhir).
  scope :fhir, defaults: { format: :json } do
    get 'metadata', to: 'fhir#metadata'
    get 'StructureDefinition/:id', to: 'fhir#structure_definition'
    get 'Observation', to: 'fhir#search'
    post 'Observation', to: 'fhir#create'
    get 'Observation/:id', to: 'fhir#show'
  end
end
