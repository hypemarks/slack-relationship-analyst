class CreateChannels < ActiveRecord::Migration
  def change
    create_table :channels do |t|
      t.string :s_id, unique: true
      t.integer :user_id
      t.integer :created

      t.timestamps null: false
    end

    add_index :channels, :user_id
  end
end
