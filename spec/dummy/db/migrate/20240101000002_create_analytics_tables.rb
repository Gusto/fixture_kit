# frozen_string_literal: true

class CreateAnalyticsTables < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_logs do |t|
      t.integer :external_user_id, null: false  # Soft FK to primary.users
      t.string :action, null: false             # e.g., "created", "completed", "commented"
      t.string :subject_type                    # e.g., "Task", "Project"
      t.integer :subject_id                     # ID of the subject in primary DB
      t.json :metadata                          # Additional context
      t.timestamps
    end

    create_table :time_entries do |t|
      t.integer :external_user_id, null: false  # Soft FK to primary.users
      t.integer :external_task_id, null: false  # Soft FK to primary.tasks
      t.decimal :hours, precision: 5, scale: 2, null: false
      t.text :description
      t.datetime :logged_at, null: false
      t.timestamps
    end

    add_index :activity_logs, :external_user_id
    add_index :activity_logs, [:subject_type, :subject_id]
    add_index :time_entries, :external_user_id
    add_index :time_entries, :external_task_id
  end
end
