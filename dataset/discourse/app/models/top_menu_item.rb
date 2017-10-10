class TopMenuItem
  def initialize(value)
    parts = value.split(',')
    @name = parts[0]
    @filter = initialize_filter(parts[1])
  end

  attr_reader :name, :filter

  def has_filter?
    filter.present?
  end

  def has_specific_category?
    name.split('/')[0] == 'category'
  end

  def specific_category
    name.split('/')[1]
  end

  private

  def initialize_filter(value)
    if value
      if value.start_with?('-')
        value[1..-1] # all but the leading -
      else
        Rails.logger.warn "WARNING: found top_menu_item with invalid filter, ignoring '#{value}'..."
        nil
      end
    end
  end
end
