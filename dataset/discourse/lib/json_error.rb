module JsonError

  def create_errors_json(obj, type=nil)
    errors = create_errors_array obj
    errors[:error_type] = type if type
    errors
  end

  private

  def create_errors_array(obj)
    return { errors: [obj] } if obj.is_a?(String)

    obj = obj.record if obj.is_a?(ActiveRecord::RecordInvalid)

    return { errors: obj.errors.full_messages } if obj.respond_to?(:errors) && obj.errors.present?

    return { errors: obj.map(&:to_s) } if obj.is_a?(Array) && obj.present?

    Rails.logger.warn("create_errors_json called with unrecognized type: #{obj.inspect}") if obj

    JsonError.generic_error
  end

  def self.generic_error
    { errors: [I18n.t('js.generic_error')] }
  end

end
