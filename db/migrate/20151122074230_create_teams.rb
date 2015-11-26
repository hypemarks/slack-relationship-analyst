class CreateTeams < ActiveRecord::Migration
  def change
    create_table :teams do |t|
      t.string :name
      t.string :s_id, unique: true
      t.timestamps null: false
    end
  end
end
