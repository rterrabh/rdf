require 'uri'
require 'json'
require 'date'

module Jekyll
  module Filters
    def markdownify(input)
      site = @context.registers[:site]
      converter = site.find_converter_instance(Jekyll::Converters::Markdown)
      converter.convert(input)
    end

    def sassify(input)
      site = @context.registers[:site]
      converter = site.find_converter_instance(Jekyll::Converters::Sass)
      converter.convert(input)
    end

    def scssify(input)
      site = @context.registers[:site]
      converter = site.find_converter_instance(Jekyll::Converters::Scss)
      converter.convert(input)
    end

    def slugify(input, mode=nil)
      Utils.slugify(input, mode)
    end

    def date_to_string(date)
      time(date).strftime("%d %b %Y")
    end

    def date_to_long_string(date)
      time(date).strftime("%d %B %Y")
    end

    def date_to_xmlschema(date)
      time(date).xmlschema
    end

    def date_to_rfc822(date)
      time(date).rfc822
    end

    def xml_escape(input)
      CGI.escapeHTML(input.to_s)
    end

    def cgi_escape(input)
      CGI::escape(input)
    end

    def uri_escape(input)
      URI.escape(input)
    end

    def number_of_words(input)
      input.split.length
    end

    def array_to_sentence_string(array)
      connector = "and"
      case array.length
      when 0
        ""
      when 1
        array[0].to_s
      when 2
        "#{array[0]} #{connector} #{array[1]}"
      else
        "#{array[0...-1].join(', ')}, #{connector} #{array[-1]}"
      end
    end

    def jsonify(input)
      as_liquid(input).to_json
    end

    def group_by(input, property)
      if groupable?(input)
        input.group_by do |item|
          item_property(item, property).to_s
        end.inject([]) do |memo, i|
          memo << {"name" => i.first, "items" => i.last}
        end
      else
        input
      end
    end

    def where(input, property, value)
      return input unless input.is_a?(Enumerable)
      input = input.values if input.is_a?(Hash)
      input.select { |object| item_property(object, property) == value }
    end

    def sort(input, property = nil, nils = "first")
      if input.nil?
          raise ArgumentError.new("Cannot sort a null object.")
      end
      if property.nil?
        input.sort
      else
        case
        when nils == "first"
          order = - 1
        when nils == "last"
          order = + 1
        else
          raise ArgumentError.new("Invalid nils order: " +
            "'#{nils}' is not a valid nils order. It must be 'first' or 'last'.")
        end

        input.sort { |apple, orange|
          apple_property = item_property(apple, property)
          orange_property = item_property(orange, property)

          if !apple_property.nil? && orange_property.nil?
            - order
          elsif apple_property.nil? && !orange_property.nil?
            + order
          else
            apple_property <=> orange_property
          end
        }
      end
    end

    def pop(array, input = 1)
      return array unless array.is_a?(Array)
      new_ary = array.dup
      new_ary.pop(input.to_i || 1)
      new_ary
    end

    def push(array, input)
      return array unless array.is_a?(Array)
      new_ary = array.dup
      new_ary.push(input)
      new_ary
    end

    def shift(array, input = 1)
      return array unless array.is_a?(Array)
      new_ary = array.dup
      new_ary.shift(input.to_i || 1)
      new_ary
    end

    def unshift(array, input)
      return array unless array.is_a?(Array)
      new_ary = array.dup
      new_ary.unshift(input)
      new_ary
    end

    def inspect(input)
      CGI.escapeHTML(input.inspect)
    end

    private
    def time(input)
      case input
      when Time
        input
      when Date
        input.to_time
      when String
        Time.parse(input) rescue Time.at(input.to_i)
      when Numeric
        Time.at(input)
      else
        Jekyll.logger.error "Invalid Date:", "'#{input}' is not a valid datetime."
        exit(1)
      end.localtime
    end

    def groupable?(element)
      element.respond_to?(:group_by)
    end

    def item_property(item, property)
      if item.respond_to?(:to_liquid)
        item.to_liquid[property.to_s]
      elsif item.respond_to?(:data)
        item.data[property.to_s]
      else
        item[property.to_s]
      end
    end

    def as_liquid(item)
      case item
      when Hash
        pairs = item.map { |k, v| as_liquid([k, v]) }
        Hash[pairs]
      when Array
        item.map{ |i| as_liquid(i) }
      else
        if item.respond_to?(:to_liquid)
          liquidated = item.to_liquid
          if liquidated == item
            item
          else
            as_liquid(liquidated)
          end
        else
          item
        end
      end
    end
  end
end
