module Diaspora
  class MessageRenderer
    class Processor
      class << self
        private :new

        def process message, options, &block
          return '' if message.blank? # Optimize for empty message
          processor = new message, options
          #nodyna <instance_exec-212> <IEX MODERATE (block without parameters)>
          processor.instance_exec(&block)
          processor.message
        end

        def normalize message
          message.gsub(/[\u202a\u202b]#[\u200e\u200f\u202d\u202e](\S+)\u202c/u, "#\\1")
        end
      end

      attr_reader :message, :options

      def initialize message, options
        @message = message
        @options = options
      end

      def squish
        @message = message.squish if options[:squish]
      end

      def append_and_truncate
        if options[:truncate]
          @message = message.truncate options[:truncate]-options[:append].to_s.size
        end

        message << options[:append].to_s
        message << options[:append_after_truncate].to_s
      end

      def escape
        if options[:escape]
          @message = ERB::Util.html_escape_once message

          @message = message.gsub(/&amp;(#[xX][\dA-Fa-f]{1,4});/, '&\1;')
        end
      end

      def strip_markdown
        renderer = Redcarpet::Markdown.new Redcarpet::Render::StripDown, options[:markdown_options]
        @message = renderer.render(message).strip
      end

      def markdownify
        renderer = Diaspora::Markdownify::HTML.new options[:markdown_render_options]
        markdown = Redcarpet::Markdown.new renderer, options[:markdown_options]

        @message = markdown.render message
      end

      def process_newlines
        message.gsub(/^[\w\<][^\n]*\n+/) do |x|
          x =~ /\n{2}/ ? x : (x.strip!; x << " \n")
        end
      end

      def render_mentions
        unless options[:disable_hovercards] || options[:mentioned_people].empty?
          @message = Diaspora::Mentionable.format message, options[:mentioned_people]
        end

        if options[:disable_hovercards] || options[:link_all_mentions]
          @message = Diaspora::Mentionable.filter_for_aspects message, nil
        else
          make_mentions_plain_text
        end
      end

      def make_mentions_plain_text
        @message = Diaspora::Mentionable.format message, [], plain_text: true
      end

      def render_tags
        @message = Diaspora::Taggable.format_tags message, no_escape: !options[:escape_tags]
      end

      def camo_urls
        @message = Diaspora::Camo.from_markdown(@message)
      end

      def normalize
        @message = self.class.normalize(@message)
      end
    end

    DEFAULTS = {mentioned_people: [],
                link_all_mentions: false,
                disable_hovercards: false,
                truncate: false,
                append: nil,
                append_after_truncate: nil,
                squish: false,
                escape: true,
                escape_tags: false,
                markdown_options: {
                  autolink: true,
                  fenced_code_blocks:  true,
                  space_after_headers: true,
                  strikethrough: true,
                  tables: true,
                  no_intra_emphasis: true,
                },
                markdown_render_options: {
                  filter_html: true,
                  hard_wrap: true,
                  safe_links_only: true
                }}.freeze

    delegate :empty?, :blank?, :present?, to: :raw

    def initialize raw_message, opts={}
      @raw_message = raw_message
      @options = DEFAULTS.deep_merge opts
    end

    def plain_text opts={}
      process(opts) {
        make_mentions_plain_text
        squish
        append_and_truncate
      }
    end

    def plain_text_without_markdown opts={}
      process(opts) {
        make_mentions_plain_text
        strip_markdown
        squish
        append_and_truncate
      }
    end

    def plain_text_for_json opts={}
      process(opts) {
        normalize
        camo_urls if AppConfig.privacy.camo.proxy_markdown_images?
      }
    end

    def html opts={}
      process(opts) {
        escape
        normalize
        render_mentions
        render_tags
        squish
        append_and_truncate
      }.html_safe
    end

    def markdownified opts={}
      process(opts) {
        process_newlines
        normalize
        camo_urls if AppConfig.privacy.camo.proxy_markdown_images?
        markdownify
        render_mentions
        render_tags
        squish
        append_and_truncate
      }.html_safe
    end

    def title opts={}
      heading = if /\A(?<setext_content>.{1,200})\n(?:={1,200}|-{1,200})(?:\r?\n|$)/ =~ @raw_message.lstrip
        setext_content
      elsif /\A\#{1,6}\s+(?<atx_content>.{1,200}?)(?:\s+#+)?(?:\r?\n|$)/ =~ @raw_message.lstrip
        atx_content
      end

      heading &&= self.class.new(heading).plain_text_without_markdown

      if heading
        heading.truncate opts.fetch(:length, 70)
      else
        plain_text_without_markdown squish: true, truncate: opts.fetch(:length, 70)
      end
    end

    def urls
      @urls ||= Twitter::Extractor.extract_urls(plain_text_without_markdown).map {|url|
        Addressable::URI.parse(url).normalize.to_s
      }
    end

    def raw
      @raw_message
    end

    def to_s
      plain_text
    end

    private

    def process opts, &block
      Processor.process(@raw_message, @options.deep_merge(opts), &block)
    end
  end
end
