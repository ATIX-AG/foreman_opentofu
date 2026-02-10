class AddTableToken < ActiveRecord::Migration[7.0]
  def change
    create_table :foreman_opentofu_tokens do |t|
      t.column :name, :string, limit: 255, index: true
      t.column :token, :string, limit: 512, index: true
      t.column :token_expire, :datetime
      t.timestamps
    end
  end
end
