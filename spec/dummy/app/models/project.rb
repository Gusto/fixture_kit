# frozen_string_literal: true

class Project < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :tasks
  has_many :comments, as: :commentable
end
