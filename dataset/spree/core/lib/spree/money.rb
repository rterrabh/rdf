
require 'money'

module Spree
  class Money
    class <<self
      attr_accessor :default_formatting_rules
    end
    self.default_formatting_rules = {
      sign_before_symbol: true
    }

    attr_reader :money

    delegate :cents, to: :money

    def initialize(amount, options={})
      @money = Monetize.parse([amount, (options[:currency] || Spree::Config[:currency])].join)
      @options = Spree::Money.default_formatting_rules.merge(options)
    end

    def to_s
      @money.format(@options)
    end

    def to_html(options = { html: true })
      output = @money.format(@options.merge(options))
      if options[:html]
        output = output.sub(" ", "&nbsp;").html_safe
      end
      output
    end

    def as_json(*)
      to_s
    end

    def ==(obj)
      @money == obj.money
    end
  end
end
