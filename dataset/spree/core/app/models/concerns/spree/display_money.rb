module Spree
  module DisplayMoney
    def money_methods(*args)
      args.each do |money_method|
        money_method = { money_method => {} } unless money_method.is_a? Hash
        money_method.each do |method_name, opts|
          #nodyna <define_method-2535> <DM MODERATE (array)>
          define_method("display_#{method_name}") do
            default_opts = respond_to?(:currency) ? { currency: currency } : {}
            #nodyna <send-2536> <SD MODERATE (array)>
            Spree::Money.new(send(method_name), default_opts.merge(opts))
          end
        end
      end
    end
  end
end
