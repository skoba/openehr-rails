# frozen_string_literal: true

require 'spec_helper'
require 'generators/openehr/install/install_generator'

describe Openehr::Generators::InstallGenerator do
  destination File.expand_path('../../../../../tmp', __FILE__)

  before(:each) do
    prepare_destination
    run_generator
  end

  it 'creates the OpenehrTemplate registry model' do
    expect(file('app/models/openehr_template.rb'))
      .to contain('include OpenehrRails::TemplateRegistry')
  end

  it 'creates the openehr_templates migration' do
    expect(migration_file('db/migrate/create_openehr_templates.rb'))
      .to contain('create_table :openehr_templates')
    expect(migration_file('db/migrate/create_openehr_templates.rb'))
      .to contain(/ActiveRecord::Migration\[\d+\.\d+\]/)
  end

  it 'creates the initializer' do
    expect(file('config/initializers/openehr.rb'))
      .to contain("require 'openehr_rails'")
  end

  it 'creates the operational template directory' do
    expect(file('app/templates/operational')).to exist
  end
end
