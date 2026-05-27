# frozen_string_literal: true

class BinaryBlob < ActiveRecord::Base
  has_many :children, class_name: "BinaryBlobChild"
  encrypts :secret_note
end
