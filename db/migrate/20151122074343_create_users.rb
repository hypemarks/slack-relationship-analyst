class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :token
      t.string :name
      t.string :avatar
      t.string :email
      t.string :s_id, unique: true
      t.integer :team_id
      t.integer :color

      t.timestamps null: false
    end

    add_index :users, :team_id
  end
end
