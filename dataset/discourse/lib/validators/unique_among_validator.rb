class UniqueAmongValidator < ActiveRecord::Validations::UniquenessValidator
  def validate_each(record, attribute, value)
    old_errors = record.errors[attribute].size

    super

    new_errors = record.errors[attribute].size - old_errors

    unless new_errors == 0
      dupes = options[:collection].call.where("lower(#{attribute}) = ?", value.downcase)
      dupes = dupes.where("id != ?", record.id) if record.persisted?

      record.errors[attribute].pop(new_errors) unless dupes.exists?
    end
  end

end
