class CreateArchetypes < ActiveRecord::Migration[7.1]
  def change
    create_table :archetypes do |t|
      t.string :archetypeid
      t.string :uid

      t.timestamps
    end
  end
end
