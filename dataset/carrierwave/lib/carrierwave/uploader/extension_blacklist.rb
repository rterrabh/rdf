module CarrierWave
  module Uploader
    module ExtensionBlacklist
      extend ActiveSupport::Concern

      included do
        before :cache, :check_blacklist!
      end

      
 
      def extension_black_list; end

    private

      def check_blacklist!(new_file)
        extension = new_file.extension.to_s
        if extension_black_list and extension_black_list.detect { |item| extension =~ /\A#{item}\z/i }
          raise CarrierWave::IntegrityError, I18n.translate(:"errors.messages.extension_black_list_error", :extension => new_file.extension.inspect, :prohibited_types => extension_black_list.join(", "))
        end
      end
    end
  end
end
