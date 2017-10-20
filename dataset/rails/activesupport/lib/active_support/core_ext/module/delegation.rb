require 'set'

class Module
  class DelegationError < NoMethodError; end

  RUBY_RESERVED_WORDS = Set.new(
    %w(alias and BEGIN begin break case class def defined? do else elsif END
       end ensure false for if in module next nil not or redo rescue retry
       return self super then true undef unless until when while yield)
  ).freeze

  def delegate(*methods)
    options = methods.pop
    unless options.is_a?(Hash) && to = options[:to]
      raise ArgumentError, 'Delegation needs a target. Supply an options hash with a :to key as the last argument (e.g. delegate :hello, to: :greeter).'
    end

    prefix, allow_nil = options.values_at(:prefix, :allow_nil)

    if prefix == true && to =~ /^[^a-z_]/
      raise ArgumentError, 'Can only automatically set the delegation prefix when delegating to a method.'
    end

    method_prefix = \
      if prefix
        "#{prefix == true ? to : prefix}_"
      else
        ''
      end

    file, line = caller.first.split(':', 2)
    line = line.to_i

    to = to.to_s
    to = "self.#{to}" if RUBY_RESERVED_WORDS.include?(to)

    methods.each do |method|
      definition = (method =~ /[^\]]=$/) ? 'arg' : '*args, &block'

      if allow_nil
        method_def = [
          "def #{method_prefix}#{method}(#{definition})",
          "_ = #{to}",
          "if !_.nil? || nil.respond_to?(:#{method})",
          "  _.#{method}(#{definition})",
          "end",
        "end"
        ].join ';'
      else
        exception = %(raise DelegationError, "#{self}##{method_prefix}#{method} delegated to #{to}.#{method}, but #{to} is nil: \#{self.inspect}")

        method_def = [
          "def #{method_prefix}#{method}(#{definition})",
          " _ = #{to}",
          "  _.#{method}(#{definition})",
          "rescue NoMethodError => e",
          "  if _.nil? && e.name == :#{method}",
          "    #{exception}",
          "  else",
          "    raise",
          "  end",
          "end"
        ].join ';'
      end

      #nodyna <module_eval-1046> <ME COMPLEX (define methods)>
      module_eval(method_def, file, line)
    end
  end
end
