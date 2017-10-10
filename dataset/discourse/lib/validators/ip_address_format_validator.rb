class IpAddressFormatValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)

    if record.ip_address.nil?
      record.errors.add(attribute, :invalid)
    end
  end

end
