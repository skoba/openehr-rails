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

  # --- openEHR RM persistence layer (mirrors the install migrations) ---
  create_table :openehr_ehrs, force: true do |t|
    t.string :ehr_id, null: false
    t.string :system_id
    t.datetime :time_created, null: false
    t.string :subject_id
    t.string :subject_namespace
    t.boolean :is_queryable, null: false, default: true
    t.boolean :is_modifiable, null: false, default: true
    t.json :other_details
    t.timestamps
  end
  add_index :openehr_ehrs, :ehr_id, unique: true

  create_table :openehr_rm_compositions, force: true do |t|
    t.references :ehr
    t.string :owner_type
    t.bigint :owner_id
    t.string :uid, null: false
    t.string :archetype_node_id, null: false
    t.string :template_id
    t.string :name_value
    t.string :language_code
    t.string :language_terminology
    t.string :territory_code
    t.string :territory_terminology
    t.string :category_code
    t.string :category_value
    t.string :composer_name
    t.datetime :context_start_time
    t.string :setting_code
    t.string :setting_value
    t.string :rm_version, null: false, default: '1.0.4'
    t.boolean :latest_version, null: false, default: true
    t.json :extra
    t.timestamps
  end
  add_index :openehr_rm_compositions, :uid
  add_index :openehr_rm_compositions, %i[owner_type owner_id]
  add_index :openehr_rm_compositions, %i[archetype_node_id latest_version]
  add_index :openehr_rm_compositions, :template_id

  create_table :openehr_rm_nodes, force: true do |t|
    t.string :rm_type, null: false
    t.references :composition, null: false
    t.bigint :parent_id
    t.string :rm_attribute_name, null: false
    t.integer :position, null: false, default: 0
    t.string :archetype_node_id
    t.string :archetype_id
    t.string :name_value
    t.string :path, null: false
    t.datetime :history_origin
    t.datetime :event_time
    t.string :width
    t.string :math_function_code
    t.string :null_flavor_code
    t.json :extra
  end
  add_index :openehr_rm_nodes, %i[composition_id path]
  add_index :openehr_rm_nodes, :parent_id
  add_index :openehr_rm_nodes, :archetype_node_id

  create_table :openehr_rm_data_values, force: true do |t|
    t.string :rm_type, null: false
    t.references :node, null: false
    t.references :composition, null: false
    t.string :rm_attribute_name, null: false, default: 'value'
    t.string :path, null: false
    t.string :text_value
    t.string :code_string
    t.string :terminology_id
    t.float :magnitude
    t.string :units
    t.integer :precision
    t.integer :integer_value
    t.boolean :boolean_value
    t.date :date_value
    t.time :time_value
    t.datetime :datetime_value
    t.string :duration_value
    t.float :numerator
    t.float :denominator
    t.integer :proportion_type
    t.string :identifier_id
    t.string :identifier_issuer
    t.string :identifier_assigner
    t.string :identifier_type
    t.string :uri_value
    t.string :media_type
    t.string :formalism
    t.json :extra
  end
  add_index :openehr_rm_data_values, :path
  add_index :openehr_rm_data_values, %i[path code_string]
  add_index :openehr_rm_data_values, %i[path magnitude]

  create_table :openehr_rm_contributions, force: true do |t|
    t.references :ehr
    t.string :uid, null: false
    t.string :system_id
    t.string :committer_name
    t.datetime :time_committed, null: false
    t.string :change_type_code, null: false
    t.string :change_type_value, null: false
    t.string :description
    t.timestamps
  end

  create_table :openehr_rm_versions, force: true do |t|
    t.string :versioned_object_uid, null: false
    t.references :composition, null: false
    t.references :contribution
    t.string :version_tree_id, null: false
    t.string :lifecycle_state_code, null: false, default: '532'
    t.string :system_id
    t.timestamps
  end
  add_index :openehr_rm_versions, %i[versioned_object_uid version_tree_id], unique: true

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

require 'openehr_rails/rm'

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
