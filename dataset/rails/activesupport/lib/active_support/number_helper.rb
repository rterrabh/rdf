module ActiveSupport
  module NumberHelper
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :NumberConverter
      autoload :NumberToRoundedConverter
      autoload :NumberToDelimitedConverter
      autoload :NumberToHumanConverter
      autoload :NumberToHumanSizeConverter
      autoload :NumberToPhoneConverter
      autoload :NumberToCurrencyConverter
      autoload :NumberToPercentageConverter
    end

    extend self

    def number_to_phone(number, options = {})
      NumberToPhoneConverter.convert(number, options)
    end

    def number_to_currency(number, options = {})
      NumberToCurrencyConverter.convert(number, options)
    end

    def number_to_percentage(number, options = {})
      NumberToPercentageConverter.convert(number, options)
    end

    def number_to_delimited(number, options = {})
      NumberToDelimitedConverter.convert(number, options)
    end

    def number_to_rounded(number, options = {})
      NumberToRoundedConverter.convert(number, options)
    end

    def number_to_human_size(number, options = {})
      NumberToHumanSizeConverter.convert(number, options)
    end

    def number_to_human(number, options = {})
      NumberToHumanConverter.convert(number, options)
    end
  end
end
