require 'active_support/xml_mini'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/object/to_query'

class Array
  def to_sentence(options = {})
    options.assert_valid_keys(:words_connector, :two_words_connector, :last_word_connector, :locale)

    default_connectors = {
      :words_connector     => ', ',
      :two_words_connector => ' and ',
      :last_word_connector => ', and '
    }
    if defined?(I18n)
      i18n_connectors = I18n.translate(:'support.array', locale: options[:locale], default: {})
      default_connectors.merge!(i18n_connectors)
    end
    options = default_connectors.merge!(options)

    case length
    when 0
      ''
    when 1
      self[0].to_s.dup
    when 2
      "#{self[0]}#{options[:two_words_connector]}#{self[1]}"
    else
      "#{self[0...-1].join(options[:words_connector])}#{options[:last_word_connector]}#{self[-1]}"
    end
  end

  def to_formatted_s(format = :default)
    case format
    when :db
      if empty?
        'null'
      else
        collect { |element| element.id }.join(',')
      end
    else
      to_default_s
    end
  end
  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s

  def to_xml(options = {})
    require 'active_support/builder' unless defined?(Builder)

    options = options.dup
    options[:indent]  ||= 2
    options[:builder] ||= Builder::XmlMarkup.new(indent: options[:indent])
    options[:root]    ||= \
      if first.class != Hash && all? { |e| e.is_a?(first.class) }
        underscored = ActiveSupport::Inflector.underscore(first.class.name)
        ActiveSupport::Inflector.pluralize(underscored).tr('/', '_')
      else
        'objects'
      end

    builder = options[:builder]
    builder.instruct! unless options.delete(:skip_instruct)

    root = ActiveSupport::XmlMini.rename_key(options[:root].to_s, options)
    children = options.delete(:children) || root.singularize
    attributes = options[:skip_types] ? {} : { type: 'array' }

    if empty?
      builder.tag!(root, attributes)
    else
      builder.tag!(root, attributes) do
        each { |value| ActiveSupport::XmlMini.to_tag(children, value, options) }
        yield builder if block_given?
      end
    end
  end
end
