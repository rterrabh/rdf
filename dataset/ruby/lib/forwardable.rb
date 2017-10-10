


module Forwardable
  FORWARDABLE_VERSION = "1.1.0"

  FILE_REGEXP = %r"#{Regexp.quote(__FILE__)}"

  @debug = nil
  class << self
    attr_accessor :debug
  end

  def instance_delegate(hash)
    hash.each{ |methods, accessor|
      methods = [methods] unless methods.respond_to?(:each)
      methods.each{ |method|
        def_instance_delegator(accessor, method)
      }
    }
  end

  def def_instance_delegators(accessor, *methods)
    methods.delete("__send__")
    methods.delete("__id__")
    for method in methods
      def_instance_delegator(accessor, method)
    end
  end

  def def_instance_delegator(accessor, method, ali = method)
    line_no = __LINE__; str = %{
      def #{ali}(*args, &block)
        begin
        rescue Exception
          $@.delete_if{|s| Forwardable::FILE_REGEXP =~ s} unless Forwardable::debug
          ::Kernel::raise
        end
      end
    }
    begin
      #nodyna <module_eval-1970> <not yet classified>
      module_eval(str, __FILE__, line_no)
    rescue
      #nodyna <instance_eval-1971> <IEV COMPLEX (private access)>
      instance_eval(str, __FILE__, line_no)
    end

  end

  alias delegate instance_delegate
  alias def_delegators def_instance_delegators
  alias def_delegator def_instance_delegator
end

module SingleForwardable
  def single_delegate(hash)
    hash.each{ |methods, accessor|
      methods = [methods] unless methods.respond_to?(:each)
      methods.each{ |method|
        def_single_delegator(accessor, method)
      }
    }
  end

  def def_single_delegators(accessor, *methods)
    methods.delete("__send__")
    methods.delete("__id__")
    for method in methods
      def_single_delegator(accessor, method)
    end
  end

  def def_single_delegator(accessor, method, ali = method)
    str = %{
      def #{ali}(*args, &block)
        begin
        rescue Exception
          $@.delete_if{|s| Forwardable::FILE_REGEXP =~ s} unless Forwardable::debug
          ::Kernel::raise
        end
      end
    }

    #nodyna <instance_eval-1972> <IEV COMPLEX (private access)>
    instance_eval(str, __FILE__, __LINE__)
  end

  alias delegate single_delegate
  alias def_delegators def_single_delegators
  alias def_delegator def_single_delegator
end
