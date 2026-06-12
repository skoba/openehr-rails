class CreateOpenehrTemplates < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :openehr_templates do |t|
      t.string :template_id, null: false
      t.string :name
      t.text :content
      t.string :template_type, null: false, default: 'operational_template'
      t.string :version

      t.timestamps
    end
    add_index :openehr_templates, :template_id, unique: true
  end
end
