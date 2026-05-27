# frozen_string_literal: true

class UuidBlob < ActiveRecord::Base
  class UuidBinaryType < ActiveModel::Type::Binary
    def serialize(value)
      return super if value.nil?

      hex = value.to_s.delete("-")
      super([hex].pack("H*"))
    end

    def deserialize(value)
      raw = super
      return raw if raw.nil?

      hex = raw.unpack1("H*")
      "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
    end
  end

  attribute :external_id, UuidBinaryType.new
end
