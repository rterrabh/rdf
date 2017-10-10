module Vagrant
  module Util
    module ShellQuote
      def self.escape(text, quote)
        text.gsub(/#{quote}/) do |m|
          "#{m}\\#{m}#{m}"
        end
      end
    end
  end
end
