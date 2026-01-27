class CreateTfState < ActiveRecord::Migration[7.0]
  def change
    create_table :tf_states do |t|
      t.string :name, limit: 255
      t.string :uuid, limit: 255
      t.text :state
      t.timestamps
    end
  end
end
