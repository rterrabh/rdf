
module CarrierWave
  module Utilities
    module Uri

    private
      def encode_path(path)
        safe_string = URI::REGEXP::PATTERN::UNRESERVED + '\/'
        unsafe = Regexp.new("[^#{safe_string}]", false)

        path.to_s.gsub(unsafe) do
          us = $&
          tmp = ''
          us.each_byte do |uc|
            tmp << sprintf('%%%02X', uc)
          end
          tmp
        end
      end
    end # Uri
  end # Utilities
end # CarrierWave
