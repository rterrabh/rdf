module ActiveAdmin
  module ViewHelpers
    module DownloadFormatLinksHelper

      def build_download_format_links(formats = self.class.formats)
        params = request.query_parameters.except :format, :commit
        div class: "download_links" do
          span I18n.t('active_admin.download')
          formats.each do |format|
            a format.upcase, href: url_for(params: params, format: format)
          end
        end
      end

      def self.included base
        base.extend ClassMethods
      end

      module ClassMethods

        def formats
          @formats ||= [:csv, :xml, :json]
          @formats.clone
        end

        def add_format(format)
          unless Mime::Type.lookup_by_extension format
            raise ArgumentError, "Please register the #{format} mime type with `Mime::Type.register`"
          end
          @formats << format unless formats.include? format
          formats
        end
      end

    end
  end
end
