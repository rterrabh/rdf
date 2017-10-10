module Spree
  module NumberGenerator
    extend ActiveSupport::Concern

    NUMBER_LENGTH  = 9
    NUMBER_LETTERS = false
    NUMBER_PREFIX  = 'N'

    included do
      before_validation :generate_number, on: :create # generate number before make_permalink
      validates :number, presence: true, uniqueness: true
    end

    def self.by_number(number)
      where(number: number)
    end

    def generate_number(options = {})
      options[:length]  ||= NUMBER_LENGTH
      options[:letters] ||= NUMBER_LETTERS
      options[:prefix]  ||= NUMBER_PREFIX

      possible = (0..9).to_a
      possible += ('A'..'Z').to_a if options[:letters]

      self.number ||= loop do
        random = "#{options[:prefix]}#{(0...options[:length]).map { possible.shuffle.first }.join}"
        if self.class.exists?(number: random)
          options[:length] += 1 if self.class.count > (10 ** options[:length] / 2)
        else
          break random
        end
      end
    end
  end
end
