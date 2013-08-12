class CreateArchetypes < ActiveRecord::Migration
  def change
    create_table :archetypes do |t|
      t.string :archetypeid
      t.string :uid

      t.timestamps
    end
  end
end
