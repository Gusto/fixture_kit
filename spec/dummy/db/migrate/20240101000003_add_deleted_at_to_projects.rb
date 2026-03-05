# frozen_string_literal: true

class AddDeletedAtToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :deleted_at, :datetime
  end
end
