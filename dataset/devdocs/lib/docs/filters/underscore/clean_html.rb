module Docs
  class Underscore
    class CleanHtmlFilter < Filter
      def call
        css('#links ~ *', '#links').remove

        doc
      end
    end
  end
end
