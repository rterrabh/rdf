require "rails/generators/named_base"

module Css # :nodoc:
  module Generators # :nodoc:
    class ScaffoldGenerator < Rails::Generators::NamedBase # :nodoc:
      def copy_stylesheet
        dir = Rails::Generators::ScaffoldGenerator.source_root
        file = File.join(dir, "scaffold.css")
        create_file "app/assets/stylesheets/scaffold.css", File.read(file)
      end
    end
  end
end
