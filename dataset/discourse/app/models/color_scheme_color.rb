class ColorSchemeColor < ActiveRecord::Base
  belongs_to :color_scheme

  validates :hex, format: { with: /\A([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/ }
end

