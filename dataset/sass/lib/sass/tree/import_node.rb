module Sass
  module Tree
    class ImportNode < RootNode
      attr_reader :imported_filename

      attr_writer :imported_file

      def initialize(imported_filename)
        @imported_filename = imported_filename
        super(nil)
      end

      def invisible?; to_s.empty?; end

      def imported_file
        @imported_file ||= import
      end

      def css_import?
        if @imported_filename =~ /\.css$/
          @imported_filename
        elsif imported_file.is_a?(String) && imported_file =~ /\.css$/
          imported_file
        end
      end

      private

      def import
        paths = @options[:load_paths]

        if @options[:importer]
          f = @options[:importer].find_relative(
            @imported_filename, @options[:filename], options_for_importer)
          return f if f
        end

        paths.each do |p|
          f = p.find(@imported_filename, options_for_importer)
          return f if f
        end

        lines = ["File to import not found or unreadable: #{@imported_filename}."]

        if paths.size == 1
          lines << "Load path: #{paths.first}"
        elsif !paths.empty?
          lines << "Load paths:\n  #{paths.join("\n  ")}"
        end
        raise SyntaxError.new(lines.join("\n"))
      rescue SyntaxError => e
        raise SyntaxError.new(e.message, :line => line, :filename => @filename)
      end

      def options_for_importer
        @options.merge(:_from_import_node => true)
      end
    end
  end
end
