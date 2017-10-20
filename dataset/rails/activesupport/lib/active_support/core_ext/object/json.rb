require 'json'
require 'bigdecimal'
require 'active_support/core_ext/big_decimal/conversions' # for #to_s
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/object/instance_variables'
require 'time'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/date_time/conversions'
require 'active_support/core_ext/date/conversions'
require 'active_support/core_ext/module/aliasing'

[Enumerable, Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  #nodyna <class_eval-1095> <CE MODERATE (define methods)>
  klass.class_eval do
    def to_json_with_active_support_encoder(options = nil) # :nodoc:
      if options.is_a?(::JSON::State)
        self.to_json_without_active_support_encoder(options)
      else
        ActiveSupport::JSON.encode(self, options)
      end
    end

    alias_method_chain :to_json, :active_support_encoder
  end
end

class Object
  def as_json(options = nil) #:nodoc:
    if respond_to?(:to_hash)
      to_hash.as_json(options)
    else
      instance_values.as_json(options)
    end
  end
end

class Struct #:nodoc:
  def as_json(options = nil)
    Hash[members.zip(values)].as_json(options)
  end
end

class TrueClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class FalseClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class NilClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class String
  def as_json(options = nil) #:nodoc:
    self
  end
end

class Symbol
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Numeric
  def as_json(options = nil) #:nodoc:
    self
  end
end

class Float
  def as_json(options = nil) #:nodoc:
    finite? ? self : nil
  end
end

class BigDecimal
  def as_json(options = nil) #:nodoc:
    finite? ? to_s : nil
  end
end

class Regexp
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

module Enumerable
  def as_json(options = nil) #:nodoc:
    to_a.as_json(options)
  end
end

class Range
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Array
  def as_json(options = nil) #:nodoc:
    map { |v| options ? v.as_json(options.dup) : v.as_json }
  end
end

class Hash
  def as_json(options = nil) #:nodoc:
    subset = if options
      if attrs = options[:only]
        slice(*Array(attrs))
      elsif attrs = options[:except]
        except(*Array(attrs))
      else
        self
      end
    else
      self
    end

    Hash[subset.map { |k, v| [k.to_s, options ? v.as_json(options.dup) : v.as_json] }]
  end
end

class Time
  def as_json(options = nil) #:nodoc:
    if ActiveSupport::JSON::Encoding.use_standard_json_time_format
      xmlschema(ActiveSupport::JSON::Encoding.time_precision)
    else
      %(#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
    end
  end
end

class Date
  def as_json(options = nil) #:nodoc:
    if ActiveSupport::JSON::Encoding.use_standard_json_time_format
      strftime("%Y-%m-%d")
    else
      strftime("%Y/%m/%d")
    end
  end
end

class DateTime
  def as_json(options = nil) #:nodoc:
    if ActiveSupport::JSON::Encoding.use_standard_json_time_format
      xmlschema(ActiveSupport::JSON::Encoding.time_precision)
    else
      strftime('%Y/%m/%d %H:%M:%S %z')
    end
  end
end

class Process::Status #:nodoc:
  def as_json(options = nil)
    { :exitstatus => exitstatus, :pid => pid }
  end
end
