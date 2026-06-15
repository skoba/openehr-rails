class CreateOpenehrRmStorage < ActiveRecord::Migration[<%= ActiveRecord::VERSION::STRING.split('.')[0..1].join('.') %>]
  def change
    create_table :openehr_rm_compositions do |t|
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
    add_index :openehr_rm_compositions, [:owner_type, :owner_id]
    add_index :openehr_rm_compositions, [:archetype_node_id, :latest_version]
    add_index :openehr_rm_compositions, :template_id

    create_table :openehr_rm_nodes do |t|
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
    add_index :openehr_rm_nodes, [:composition_id, :path]
    add_index :openehr_rm_nodes, :parent_id
    add_index :openehr_rm_nodes, :archetype_node_id

    create_table :openehr_rm_data_values do |t|
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
    add_index :openehr_rm_data_values, [:path, :code_string]
    add_index :openehr_rm_data_values, [:path, :magnitude]
  end
end
