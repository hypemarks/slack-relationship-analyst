class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.integer :user_id_to
      t.integer :user_id_from
      t.integer :channel_id
      t.string :s_type
      t.float :ts
      t.text :text

      t.timestamps null: false
    end

    add_index :messages, :user_id_to
    add_index :messages, :user_id_from
    add_index :messages, :channel_id
    add_index :messages, :ts
  end
end
