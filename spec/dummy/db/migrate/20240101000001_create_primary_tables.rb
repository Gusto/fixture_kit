# frozen_string_literal: true

class CreatePrimaryTables < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :role, default: "member"
      t.timestamps
    end

    create_table :projects do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, default: "active"
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :tasks do |t|
      t.string :title, null: false
      t.text :description
      t.string :status, default: "pending"
      t.date :due_date
      t.references :project, null: false, foreign_key: true
      t.references :assignee, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :comments do |t|
      t.text :body, null: false
      t.references :commentable, polymorphic: true, null: false
      t.timestamps
    end
  end
end
