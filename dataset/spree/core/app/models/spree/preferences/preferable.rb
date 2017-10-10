module Spree::Preferences::Preferable
  extend ActiveSupport::Concern

  included do
    extend Spree::Preferences::PreferableClassMethods
  end

  def get_preference(name)
    has_preference! name
    #nodyna <send-2508> <SD COMPLEX (change-prone variables)>
    send self.class.preference_getter_method(name)
  end

  def set_preference(name, value)
    has_preference! name
    #nodyna <send-2509> <SD COMPLEX (change-prone variables)>
    send self.class.preference_setter_method(name), value
  end

  def preference_type(name)
    has_preference! name
    #nodyna <send-2510> <SD COMPLEX (change-prone variables)>
    send self.class.preference_type_getter_method(name)
  end

  def preference_default(name)
    has_preference! name
    #nodyna <send-2511> <SD COMPLEX (change-prone variables)>
    send self.class.preference_default_getter_method(name)
  end

  def has_preference!(name)
    raise NoMethodError.new "#{name} preference not defined" unless has_preference? name
  end

  def has_preference?(name)
    respond_to? self.class.preference_getter_method(name)
  end

  def defined_preferences
    methods.grep(/\Apreferred_.*=\Z/).map do |pref_method|
      pref_method.to_s.gsub(/\Apreferred_|=\Z/, '').to_sym
    end
  end

  def default_preferences
    Hash[
      defined_preferences.map do |preference|
        [preference, preference_default(preference)]
      end
    ]
  end

  def clear_preferences
    preferences.keys.each {|pref| preferences.delete pref}
  end

  private

  def convert_preference_value(value, type)
    case type
    when :string, :text
      value.to_s
    when :password
      value.to_s
    when :decimal
      BigDecimal.new(value.to_s)
    when :integer
      value.to_i
    when :boolean
      if value.is_a?(FalseClass) ||
         value.nil? ||
         value == 0 ||
         value =~ /^(f|false|0)$/i ||
         (value.respond_to? :empty? and value.empty?)
         false
      else
         true
      end
    when :array
      value.is_a?(Array) ? value : Array.wrap(value)
    when :hash
      case value.class.to_s
      when "Hash"
        value
      when "String"
        JSON.parse value.gsub('=>', ':')
      when "Array"
        begin
          value.try(:to_h)
        rescue TypeError
          Hash[*value]
        rescue ArgumentError
          raise 'An even count is required when passing an array to be converted to a hash'
        end
      else
        value.class.ancestors.include?(Hash) ? value : {}
      end
    else
      value
    end
  end
end
