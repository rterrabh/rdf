require 'active_support/option_merger'

class Object
  def with_options(options, &block)
    option_merger = ActiveSupport::OptionMerger.new(self, options)
    #nodyna <instance_eval-1092> <IEV COMPLEX (block execution)>
    block.arity.zero? ? option_merger.instance_eval(&block) : block.call(option_merger)
  end
end
