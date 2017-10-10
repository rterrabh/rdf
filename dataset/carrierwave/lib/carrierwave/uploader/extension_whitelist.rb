
module CarrierWave
  module Uploader
    module ExtensionWhitelist
      extend ActiveSupport::Concern

      included do
        before :cache, :check_whitelist!
      end

      def extension_white_list; end

    private

      def check_whitelist!(new_file)
        extension = new_file.extension.to_s
        if extension_white_list and not extension_white_list.detect { |item| extension =~ /\A#{item}\z/i }
          raise CarrierWave::IntegrityError, I18n.translate(:"errors.messages.extension_white_list_error", :extension => new_file.extension.inspect, :allowed_types => extension_white_list.join(", "))
        end
      end

    end # ExtensionWhitelist
  end # Uploader
end # CarrierWave
