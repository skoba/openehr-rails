class CreateRms < ActiveRecord::Migration[7.1]
  def change
    create_table :rms do |t|
      t.string :node_id
      t.string :path
      t.references :archetype, index: true
      t.string :text_value
      t.float :num_value
      t.date :date_value
      t.time :time_value
      t.datetime :datetime_value
      t.boolean :bool_value

      t.timestamps
    end
  end
end
