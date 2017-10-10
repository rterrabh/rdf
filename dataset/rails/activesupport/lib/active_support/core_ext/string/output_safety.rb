require 'erb'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/deprecation'

class ERB
  module Util
    HTML_ESCAPE = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;', "'" => '&#39;' }
    JSON_ESCAPE = { '&' => '\u0026', '>' => '\u003e', '<' => '\u003c', "\u2028" => '\u2028', "\u2029" => '\u2029' }
    HTML_ESCAPE_REGEXP = /[&"'><]/
    HTML_ESCAPE_ONCE_REGEXP = /["><']|&(?!([a-zA-Z]+|(#\d+)|(#[xX][\dA-Fa-f]+));)/
    JSON_ESCAPE_REGEXP = /[\u2028\u2029&><]/u

    def html_escape(s)
      unwrapped_html_escape(s).html_safe
    end

    remove_method(:h)
    alias h html_escape

    module_function :h

    #nodyna <send-1057> <SD COMPLEX (private methods)>
    singleton_class.send(:remove_method, :html_escape)
    module_function :html_escape

    def unwrapped_html_escape(s) # :nodoc:
      s = s.to_s
      if s.html_safe?
        s
      else
        s.gsub(HTML_ESCAPE_REGEXP, HTML_ESCAPE)
      end
    end
    module_function :unwrapped_html_escape

    def html_escape_once(s)
      result = s.to_s.gsub(HTML_ESCAPE_ONCE_REGEXP, HTML_ESCAPE)
      s.html_safe? ? result.html_safe : result
    end

    module_function :html_escape_once

    def json_escape(s)
      result = s.to_s.gsub(JSON_ESCAPE_REGEXP, JSON_ESCAPE)
      s.html_safe? ? result.html_safe : result
    end

    module_function :json_escape
  end
end

class Object
  def html_safe?
    false
  end
end

class Numeric
  def html_safe?
    true
  end
end

module ActiveSupport #:nodoc:
  class SafeBuffer < String
    UNSAFE_STRING_METHODS = %w(
      capitalize chomp chop delete downcase gsub lstrip next reverse rstrip
      slice squeeze strip sub succ swapcase tr tr_s upcase
    )

    alias_method :original_concat, :concat
    private :original_concat

    class SafeConcatError < StandardError
      def initialize
        super 'Could not concatenate to the buffer because it is not html safe.'
      end
    end

    def [](*args)
      if args.size < 2
        super
      else
        if html_safe?
          new_safe_buffer = super

          if new_safe_buffer
            #nodyna <instance_variable_set-1058> <not yet classified>
            new_safe_buffer.instance_variable_set :@html_safe, true
          end

          new_safe_buffer
        else
          to_str[*args]
        end
      end
    end

    def safe_concat(value)
      raise SafeConcatError unless html_safe?
      original_concat(value)
    end

    def initialize(*)
      @html_safe = true
      super
    end

    def initialize_copy(other)
      super
      @html_safe = other.html_safe?
    end

    def clone_empty
      self[0, 0]
    end

    def concat(value)
      super(html_escape_interpolated_argument(value))
    end
    alias << concat

    def prepend(value)
      super(html_escape_interpolated_argument(value))
    end

    def prepend!(value)
      ActiveSupport::Deprecation.deprecation_warning "ActiveSupport::SafeBuffer#prepend!", :prepend
      prepend value
    end

    def +(other)
      dup.concat(other)
    end

    def %(args)
      case args
      when Hash
        escaped_args = Hash[args.map { |k,arg| [k, html_escape_interpolated_argument(arg)] }]
      else
        escaped_args = Array(args).map { |arg| html_escape_interpolated_argument(arg) }
      end

      self.class.new(super(escaped_args))
    end

    def html_safe?
      defined?(@html_safe) && @html_safe
    end

    def to_s
      self
    end

    def to_param
      to_str
    end

    def encode_with(coder)
      coder.represent_object nil, to_str
    end

    UNSAFE_STRING_METHODS.each do |unsafe_method|
      if unsafe_method.respond_to?(unsafe_method)
        #nodyna <class_eval-1059> <not yet classified>
        class_eval <<-EOT, __FILE__, __LINE__ + 1
          def #{unsafe_method}(*args, &block)       # def capitalize(*args, &block)
            to_str.#{unsafe_method}(*args, &block)  #   to_str.capitalize(*args, &block)
          end                                       # end

          def #{unsafe_method}!(*args)              # def capitalize!(*args)
            @html_safe = false                      #   @html_safe = false
            super                                   #   super
          end                                       # end
        EOT
      end
    end

    private

    def html_escape_interpolated_argument(arg)
      (!html_safe? || arg.html_safe?) ? arg :
        arg.to_s.gsub(ERB::Util::HTML_ESCAPE_REGEXP, ERB::Util::HTML_ESCAPE)
    end
  end
end

class String
  def html_safe
    ActiveSupport::SafeBuffer.new(self)
  end
end
