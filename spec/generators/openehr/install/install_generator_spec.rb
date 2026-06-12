# frozen_string_literal: true

require 'spec_helper'
require 'generators/openehr/install/install_generator'

describe Openehr::Generators::InstallGenerator do
  destination File.expand_path('../../../../../tmp', __FILE__)

  before(:each) do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, 'config'))
    File.write(File.join(destination_root, 'config/routes.rb'),
               "Rails.application.routes.draw do\nend\n")
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

  it 'mounts the admin engine' do
    expect(file('config/routes.rb'))
      .to contain("mount OpenehrRails::Engine => '/openehr'")
  end
end
