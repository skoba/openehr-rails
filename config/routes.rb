OpenehrRails::Engine.routes.draw do
  root to: 'templates#index'

  resources :templates, only: %i[index create destroy] do
    member do
      post :generate
    end
  end

  # AQL query console (HTML). Executes against the same JSON API below
  # (POST /v1/query/aql) via fetch, so there is exactly one execution path.
  get 'query', to: 'queries#show', as: :query_console

  # Patient timeline: cross-template view of everything recorded against
  # one EHR, grouped by date. :id is the ehr_id (openEHR EHR identifier).
  resources :ehrs, only: %i[index show]

  # HL7 FHIR R5 facade (base URL: <mount-point>/fhir).
  scope :fhir, defaults: { format: :json } do
    get 'metadata', to: 'fhir#metadata'
    get 'StructureDefinition/:id', to: 'fhir#structure_definition'
    get 'Observation', to: 'fhir#search'
    post 'Observation', to: 'fhir#create'
    get 'Observation/:id', to: 'fhir#show'
  end

  # openEHR REST API (base URL: <mount-point>/v1). uid path segments carry
  # literal "::" (object_version_id = uid::system_id::version_tree_id), so
  # every :uid/:versioned_uid route disables the default dot-as-format
  # inference with format: false and matches the rest via a permissive regex.
  scope :v1, defaults: { format: :json } do
    match 'query/aql', to: 'queries#execute', via: %i[get post]

    post 'ehr', to: 'openehr_api/ehrs#create', as: :create_ehr
    put 'ehr/:ehr_id', to: 'openehr_api/ehrs#upsert', as: :upsert_ehr
    get 'ehr/:ehr_id', to: 'openehr_api/ehrs#show', as: :api_ehr
    get 'ehr/:ehr_id/ehr_status', to: 'openehr_api/ehrs#ehr_status', as: :ehr_status

    post 'ehr/:ehr_id/composition', to: 'openehr_api/compositions#create', as: :create_composition
    get 'ehr/:ehr_id/composition/:uid', to: 'openehr_api/compositions#show',
                                        as: :composition, format: false, constraints: { uid: /.+/ }
    put 'ehr/:ehr_id/composition/:uid', to: 'openehr_api/compositions#update',
                                        as: :update_composition, format: false, constraints: { uid: /.+/ }
    delete 'ehr/:ehr_id/composition/:uid', to: 'openehr_api/compositions#destroy',
                                           as: :destroy_composition, format: false, constraints: { uid: /.+/ }
  end
end
