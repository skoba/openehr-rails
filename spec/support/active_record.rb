# frozen_string_literal: true

require 'active_record'
require 'openehr_rails'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :openehr_templates, force: true do |t|
    t.string :template_id, null: false
    t.string :name
    t.text :content
    t.string :template_type, null: false, default: 'operational_template'
    t.string :version
    t.timestamps
  end
  add_index :openehr_templates, :template_id, unique: true

  # Table backing the Storable/AqlQueryable specs; mirrors what
  # `rails g openehr:scaffold bmi_calculation.opt` generates.
  create_table :bmi_calculations, force: true do |t|
    t.float :height
    t.string :height_units, default: 'cm'
    t.float :body_weight
    t.string :body_weight_units, default: 'kg'
    t.float :body_mass_index
    t.string :body_mass_index_units, default: 'kg/m2'
    t.string :body_mass_index_at0013
    t.string :ehr_id
    t.datetime :composed_at
    t.json :rm_composition
    t.string :template_id, null: false, default: 'bmi_calculation'
    t.string :uid
    t.timestamps
  end
end

# Test double for the model the install generator emits.
class OpenehrTemplate < ActiveRecord::Base
  include OpenehrRails::TemplateRegistry
end

RSpec.configure do |config|
  config.around(:each) do |example|
    if ActiveRecord::Base.connected?
      ActiveRecord::Base.transaction do
        example.run
        raise ActiveRecord::Rollback
      end
    else
      example.run
    end
  end
end
