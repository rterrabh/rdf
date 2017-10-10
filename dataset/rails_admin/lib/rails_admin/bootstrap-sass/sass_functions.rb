require 'sass'

module Sass
  module Script
    module Functions
      def ie_hex_str(color)
        assert_type color, :Color
        alpha = (color.alpha * 255).round
        alphastr = alpha.to_s(16).rjust(2, '0')
        #nodyna <send-1425> <SD TRIVIAL (public methods)>
        Sass::Script::String.new("##{alphastr}#{color.send(:hex_str)[1..-1]}".upcase)
      end
      declare :ie_hex_str, [:color]
    end
  end
end
