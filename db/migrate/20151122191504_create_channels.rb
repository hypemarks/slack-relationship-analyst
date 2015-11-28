class CreateChannels < ActiveRecord::Migration
  def change
    create_table :channels do |t|
      t.string :s_id, unique: true
      t.integer :created
      t.timestamps null: false
    end
  end
end
