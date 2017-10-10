module Sass
  module Script
    module Functions
      def image_path(source, _options = {})
        if defined?(::Sprockets)
          ::Sass::Script::String.new sprockets_context.image_path(source.value).to_s, :string
        elsif defined?(::Compass)
          image_url(source, Sass::Script::Bool.new(true))
        else
          asset_sans_quotes = source.value.gsub('"', '')
          Sass::Script::String.new("/images/#{asset_sans_quotes}", :string)
        end
      end

    protected

      def sprockets_context # :nodoc:
        if options.key?(:sprockets)
          options[:sprockets][:context]
        else
          options[:importer].context
        end
      end
    end
  end
end
