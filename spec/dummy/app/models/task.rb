# frozen_string_literal: true

class Task < ApplicationRecord
  belongs_to :project
  belongs_to :assignee, class_name: "User"
  has_many :comments, as: :commentable
end
