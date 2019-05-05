class InitialDbMigration < ActiveRecord::Migration[5.2]
  def change
    create_table :permalinks do |t|
      t.string    :link
      t.datetime  :timestamp, default: -> { 'CURRENT_TIMESTAMP' }
    end

    create_table :unsubscribed do |t|
      t.string    :username
      t.datetime  :timestamp, default: -> { 'CURRENT_TIMESTAMP' }
    end

    add_index :permalinks,    :link,      unique: true
    add_index :unsubscribed,  :username,  unique: true
  end
end
