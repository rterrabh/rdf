module Jekyll
  module Converters
    class Markdown < Converter
      safe true

      highlighter_prefix "\n"
      highlighter_suffix "\n"

      def setup
        return if @setup
        @parser =
          case @config['markdown'].downcase
            when 'redcarpet' then RedcarpetParser.new(@config)
            when 'kramdown'  then KramdownParser.new(@config)
            when 'rdiscount' then RDiscountParser.new(@config)
          else
            if allowed_custom_class?(@config['markdown'])
              #nodyna <const_get-2945> <CG COMPLEX (change-prone variable)>
              self.class.const_get(@config['markdown']).new(@config)
            else
              Jekyll.logger.error "Invalid Markdown Processor:", "#{@config['markdown']}"
              Jekyll.logger.error "", "Valid options are [ #{valid_processors.join(" | ")} ]"
              raise Errors::FatalException, "Invalid Markdown Processor: #{@config['markdown']}"
            end
          end
        @setup = true
      end

      def valid_processors
        %w[
          rdiscount
          kramdown
          redcarpet
        ] + third_party_processors
      end

      def third_party_processors
        self.class.constants - %w[
          KramdownParser
          RDiscountParser
          RedcarpetParser
          PRIORITIES
        ].map(&:to_sym)
      end

      def extname_list
        @extname_list ||= @config['markdown_ext'].split(',').map { |e| ".#{e.downcase}" }
      end

      def matches(ext)
        extname_list.include? ext.downcase
      end

      def output_ext(ext)
        ".html"
      end

      def convert(content)
        setup
        @parser.convert(content)
      end

      private

      def allowed_custom_class?(parser_name)
        parser_name !~ /[^A-Za-z0-9]/ && self.class.constants.include?(parser_name.to_sym)
      end
    end
  end
end
