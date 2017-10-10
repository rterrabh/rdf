module LiquidInterpolatable
  extend ActiveSupport::Concern

  included do
    validate :validate_interpolation
  end

  def valid?(context = nil)
    super
  rescue Liquid::Error
    errors.empty?
  end

  def validate_interpolation
    interpolated
  rescue Liquid::Error => e
    errors.add(:options, "has an error with Liquid templating: #{e.message}")
  rescue
  end

  def interpolation_context
    @interpolation_context ||= Context.new(self)
  end

  def interpolate_with(self_object)
    case self_object
    when nil
      yield
    else
      context = interpolation_context
      begin
        context.environments.unshift(self_object.to_liquid)
        yield
      ensure
        context.environments.shift
      end
    end
  end

  def interpolate_options(options, self_object = nil)
    interpolate_with(self_object) do
      case options
      when String
        interpolate_string(options)
      when ActiveSupport::HashWithIndifferentAccess, Hash
        options.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) { |(key, value), memo|
          memo[key] = interpolate_options(value)
        }
      when Array
        options.map { |value| interpolate_options(value) }
      else
        options
      end
    end
  end

  def interpolated(self_object = nil)
    interpolate_with(self_object) do
      (@interpolated_cache ||= {})[[options, interpolation_context]] ||=
        interpolate_options(options)
    end
  end

  def interpolate_string(string, self_object = nil)
    interpolate_with(self_object) do
      Liquid::Template.parse(string).render!(interpolation_context)
    end
  end

  class Context < Liquid::Context
    def initialize(agent)
      super({}, {}, { agent: agent }, true)
    end

    def hash
      [@environments, @scopes, @registers].hash
    end

    def eql?(other)
      other.environments == @environments &&
        other.scopes == @scopes &&
        other.registers == @registers
    end
  end

  require 'uri'
  module Filters
    def uri_escape(string)
      CGI.escape(string) rescue string
    end

    def to_uri(uri, base_uri = nil)
      if base_uri
        URI(base_uri) + uri.to_s
      else
        URI(uri.to_s)
      end
    rescue URI::Error
      nil
    end

    def uri_expand(url, limit = 5)
      case url
      when URI
        uri = url
      else
        url = url.to_s
        begin
          uri = URI(url)
        rescue URI::Error
          return url
        end
      end

      http = Faraday.new do |builder|
        builder.adapter :net_http
      end

      limit.times do
        begin
          case uri
          when URI::HTTP
            return uri.to_s unless uri.host
            response = http.head(uri)
            case response.status
            when 301, 302, 303, 307
              if location = response['location']
                uri += location
                next
              end
            end
          end
        rescue URI::Error, Faraday::Error, SystemCallError => e
          logger.error "#{e.class} in #{__method__}(#{url.inspect}) [uri=#{uri.to_s.inspect}]: #{e.message}:\n#{e.backtrace.join("\n")}"
        end

        return uri.to_s
      end

      logger.error "Too many rediretions in #{__method__}(#{url.inspect}) [uri=#{uri.to_s.inspect}]"

      url
    end

    def unescape(input)
      CGI.unescapeHTML(input) rescue input
    end

    def to_xpath(string)
      subs = string.to_s.scan(/\G(?:\A\z|[^"]+|[^']+)/).map { |x|
        case x
        when /"/
          %Q{'#{x}'}
        else
          %Q{"#{x}"}
        end
      }
      if subs.size == 1
        subs.first
      else
        'concat(' << subs.join(', ') << ')'
      end
    end

    def regex_replace(input, regex, replacement = nil)
      input.to_s.gsub(Regexp.new(regex), unescape_replacement(replacement.to_s))
    end

    def regex_replace_first(input, regex, replacement = nil)
      input.to_s.sub(Regexp.new(regex), unescape_replacement(replacement.to_s))
    end

    private

    def logger
      @@logger ||=
        if defined?(Rails)
          Rails.logger
        else
          require 'logger'
          Logger.new(STDERR)
        end
    end

    BACKSLASH = "\\".freeze

    UNESCAPE = {
      "a" => "\a",
      "b" => "\b",
      "e" => "\e",
      "f" => "\f",
      "n" => "\n",
      "r" => "\r",
      "s" => " ",
      "t" => "\t",
      "v" => "\v",
    }

    def unescape_replacement(s)
      s.gsub(/\\(?:([\d+&`'\\]|k<\w+>)|u\{([[:xdigit:]]+)\}|x([[:xdigit:]]{2})|(.))/) {
        if c = $1
          BACKSLASH + c
        elsif c = ($2 && [$2.to_i(16)].pack('U')) ||
                  ($3 && [$3.to_i(16)].pack('C'))
          if c == BACKSLASH
            BACKSLASH + c
          else
            c
          end
        else
          UNESCAPE[$4] || $4
        end
      }
    end
  end
  Liquid::Template.register_filter(LiquidInterpolatable::Filters)

  module Tags
    class Credential < Liquid::Tag
      def initialize(tag_name, name, tokens)
        super
        @credential_name = name.strip
      end

      def render(context)
        credential = context.registers[:agent].credential(@credential_name)
        raise "No user credential named '#{@credential_name}' defined" if credential.nil?
        credential
      end
    end

    class LineBreak < Liquid::Tag
      def render(context)
        "\n"
      end
    end
  end
  Liquid::Template.register_tag('credential', LiquidInterpolatable::Tags::Credential)
  Liquid::Template.register_tag('line_break', LiquidInterpolatable::Tags::LineBreak)
end
