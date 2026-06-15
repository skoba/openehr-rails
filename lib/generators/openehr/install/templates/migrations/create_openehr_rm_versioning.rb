class CreateOpenehrRmVersioning < ActiveRecord::Migration[<%= ActiveRecord::VERSION::STRING.split('.')[0..1].join('.') %>]
  def change
    create_table :openehr_rm_contributions do |t|
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

    create_table :openehr_rm_versions do |t|
      t.string :versioned_object_uid, null: false
      t.references :composition, null: false
      t.references :contribution
      t.string :version_tree_id, null: false
      t.string :lifecycle_state_code, null: false, default: '532'
      t.string :system_id
      t.timestamps
    end
    add_index :openehr_rm_versions,
              [:versioned_object_uid, :version_tree_id],
              unique: true
  end
end
