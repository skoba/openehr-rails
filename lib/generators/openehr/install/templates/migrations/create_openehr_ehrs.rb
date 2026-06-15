class CreateOpenehrEhrs < ActiveRecord::Migration[<%= ActiveRecord::VERSION::STRING.split('.')[0..1].join('.') %>]
  def change
    create_table :openehr_ehrs do |t|
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
  end
end
