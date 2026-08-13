# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative '../../app/controllers/openehr_rails/application_controller'

describe 'OpenehrRails engine authentication' do
  after do
    OpenehrRails.authenticate_with = nil
    OpenehrRails.allow_unauthenticated_access = nil
  end

  describe '.unauthenticated_access_allowed?' do
    def stub_env(name)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new(name))
    end

    it 'is true in development when unconfigured' do
      stub_env('development')
      expect(OpenehrRails.unauthenticated_access_allowed?).to be true
    end

    it 'is true in test when unconfigured' do
      stub_env('test')
      expect(OpenehrRails.unauthenticated_access_allowed?).to be true
    end

    it 'is false in production when unconfigured' do
      stub_env('production')
      expect(OpenehrRails.unauthenticated_access_allowed?).to be false
    end

    it 'honours an explicit true override even in production' do
      stub_env('production')
      OpenehrRails.allow_unauthenticated_access = true
      expect(OpenehrRails.unauthenticated_access_allowed?).to be true
    end

    it 'honours an explicit false override even in development' do
      stub_env('development')
      OpenehrRails.allow_unauthenticated_access = false
      expect(OpenehrRails.unauthenticated_access_allowed?).to be false
    end
  end

  describe OpenehrRails::ApplicationController do
    subject(:controller) { described_class.new }

    def stub_request(json: true)
      allow(controller).to receive(:request).and_return(
        instance_double(ActionDispatch::Request, format: double('format', json?: json))
      )
    end

    before do
      allow(controller).to receive(:render)
      stub_request
    end

    it 'defaults openehr_access_scope to :admin' do
      expect(controller.openehr_access_scope).to eq(:admin)
    end

    context 'when no hook is configured' do
      it 'allows the request in development/test (unauthenticated_access_allowed? true)' do
        allow(OpenehrRails).to receive(:unauthenticated_access_allowed?).and_return(true)

        controller.send(:authenticate_openehr_access!)

        expect(controller).not_to have_received(:render)
      end

      it 'denies the request with 403 JSON outside development/test' do
        allow(OpenehrRails).to receive(:unauthenticated_access_allowed?).and_return(false)
        stub_request(json: true)

        controller.send(:authenticate_openehr_access!)

        expect(controller).to have_received(:render).with(hash_including(status: :forbidden, json: anything))
      end

      it 'denies non-JSON requests with a plain-text 403' do
        allow(OpenehrRails).to receive(:unauthenticated_access_allowed?).and_return(false)
        stub_request(json: false)

        controller.send(:authenticate_openehr_access!)

        expect(controller).to have_received(:render).with(hash_including(status: :forbidden, plain: anything))
      end
    end

    context 'when a hook is configured' do
      it 'defers entirely to the hook, even outside development/test' do
        allow(OpenehrRails).to receive(:unauthenticated_access_allowed?).and_return(false)
        ran = false
        OpenehrRails.authenticate_with = -> { ran = true }

        controller.send(:authenticate_openehr_access!)

        expect(ran).to be true
        expect(controller).not_to have_received(:render)
      end

      it 'instance_execs the hook in controller context so it can call controller methods' do
        def controller.custom_auth_check
          render plain: 'nope', status: :unauthorized
        end
        OpenehrRails.authenticate_with = -> { custom_auth_check }

        controller.send(:authenticate_openehr_access!)

        expect(controller).to have_received(:render).with(hash_including(status: :unauthorized))
      end
    end
  end

  describe 'openehr_access_scope overrides' do
    require_relative '../../app/controllers/openehr_rails/fhir_controller'
    require_relative '../../app/controllers/openehr_rails/queries_controller'
    require_relative '../../app/controllers/openehr_rails/openehr_api/ehrs_controller'
    require_relative '../../app/controllers/openehr_rails/openehr_api/compositions_controller'

    it 'is :fhir for FhirController' do
      expect(OpenehrRails::FhirController.new.openehr_access_scope).to eq(:fhir)
    end

    it 'is :rest_api for OpenehrApi::EhrsController and OpenehrApi::CompositionsController' do
      expect(OpenehrRails::OpenehrApi::EhrsController.new.openehr_access_scope).to eq(:rest_api)
      expect(OpenehrRails::OpenehrApi::CompositionsController.new.openehr_access_scope).to eq(:rest_api)
    end

    it 'is :rest_api for QueriesController#execute and :admin for QueriesController#show' do
      controller = OpenehrRails::QueriesController.new
      allow(controller).to receive(:action_name).and_return('execute')
      expect(controller.openehr_access_scope).to eq(:rest_api)

      allow(controller).to receive(:action_name).and_return('show')
      expect(controller.openehr_access_scope).to eq(:admin)
    end
  end
end
