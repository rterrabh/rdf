module Spree
  class LocalizedNumber

    def self.parse(number)
      return number unless number.is_a?(String)

      separator, delimiter = I18n.t([:'number.currency.format.separator', :'number.currency.format.delimiter'])
      non_number_characters = /[^0-9\-#{separator}]/

      number.gsub!(non_number_characters, '')
      number.gsub!(separator, '.') unless separator == '.'

      number.to_d
    end

  end
end
