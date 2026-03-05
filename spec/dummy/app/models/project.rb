# frozen_string_literal: true

class Project < ApplicationRecord
  default_scope { where(deleted_at: nil) }

  belongs_to :owner, class_name: "User"
  has_many :tasks
  has_many :comments, as: :commentable
end
