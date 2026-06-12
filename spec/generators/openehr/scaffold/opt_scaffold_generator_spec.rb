# frozen_string_literal: true

require 'spec_helper'
require 'generators/openehr/scaffold/scaffold_generator'

module Openehr
  module Generators
    describe ScaffoldGenerator, 'with OPT file' do
      destination File.expand_path('../../../../../tmp', __FILE__)

      let(:opt_file) { File.expand_path('../../../templates/bmi_calculation.opt', __FILE__) }

      before(:each) do
        prepare_destination
        FileUtils.mkdir_p(File.join(destination_root, 'config'))
        File.write(File.join(destination_root, 'config/routes.rb'),
                   "Rails.application.routes.draw do\nend\n")
        run_generator [opt_file]
      end

      context 'model' do
        subject { file('app/models/bmi_calculation.rb') }

        it { is_expected.to exist }
        it { is_expected.to contain 'class BmiCalculation < ApplicationRecord' }
        it { is_expected.to contain 'include OpenehrRails::Storable' }
        it { is_expected.to contain 'include OpenehrRails::AqlQueryable' }
        it { is_expected.to contain "TEMPLATE_ID = 'bmi_calculation'" }
        it { is_expected.to contain "ROOT_ARCHETYPE_ID = 'openEHR-EHR-COMPOSITION.report-result.v1'" }
        it { is_expected.to contain 'FIELD_MAP' }
        it { is_expected.to contain "'height' =>" }
        it { is_expected.to contain "'body_weight' =>" }
        it { is_expected.to contain(/validates :height, numericality/) }
      end

      context 'migration' do
        subject { migration_file('db/migrate/create_bmi_calculations.rb') }

        # NOTE: ammeter's bare `exist` matcher is incompatible with Rails 8.1
        # deprecation API; `contain` implies existence.
        it { is_expected.to contain 'class CreateBmiCalculations < ActiveRecord::Migration' }
        it { is_expected.to contain 'create_table :bmi_calculations' }
        it { is_expected.to contain 't.float :height' }
        it { is_expected.to contain "t.string :height_units, default: 'cm'" }
        it { is_expected.to contain 't.float :body_weight' }
        it { is_expected.to contain 't.json :rm_composition' }
        it { is_expected.to contain 't.string :template_id, null: false' }
      end

      context 'controller' do
        subject { file('app/controllers/bmi_calculations_controller.rb') }

        it { is_expected.to exist }
        it { is_expected.to contain 'class BmiCalculationsController < ApplicationController' }
        it { is_expected.to contain 'params.require(:bmi_calculation)' }
        it { is_expected.to contain ':height, :body_weight' }
      end

      context 'views' do
        let(:view_dir) { 'app/views/bmi_calculations' }

        context 'index.html.erb' do
          subject { file("#{view_dir}/index.html.erb") }

          it { is_expected.to exist }
          it { is_expected.to contain 'human_attribute_name(:height)' }
          it { is_expected.to contain 'human_attribute_name(:body_weight)' }
        end

        context 'show.html.erb' do
          subject { file("#{view_dir}/show.html.erb") }

          it { is_expected.to exist }
          it { is_expected.to contain 'human_attribute_name(:height)' }
        end

        context '_form.html.erb' do
          subject { file("#{view_dir}/_form.html.erb") }

          it { is_expected.to exist }
          it { is_expected.to contain 'f.number_field :height' }
          it { is_expected.to contain 'f.number_field :body_weight' }
          it { is_expected.to contain 'f.text_field :body_mass_index_at0013' }
        end

        %w[new edit].each do |view|
          context "#{view}.html.erb" do
            subject { file("#{view_dir}/#{view}.html.erb") }

            it { is_expected.to exist }
          end
        end
      end

      context 'routes' do
        subject { file('config/routes.rb') }

        it { is_expected.to contain 'resources :bmi_calculations' }
      end

      context 'i18n locale' do
        subject { file('config/locales/bmi_calculation.en.yml') }

        it { is_expected.to exist }
        it { is_expected.to contain '身長' }
        it { is_expected.to contain '体重' }
      end

      context 'template registration' do
        it 'copies the OPT into the app' do
          expect(file('app/templates/operational/bmi_calculation.opt')).to exist
        end

        it 'registers the template in db/seeds.rb' do
          expect(file('db/seeds.rb')).to contain 'OpenehrTemplate.from_opt_file'
        end
      end

      context 'request spec' do
        subject { file('spec/requests/bmi_calculations_spec.rb') }

        it { is_expected.to exist }
        it { is_expected.to contain "describe '/bmi_calculations'" }
      end
    end
  end
end
