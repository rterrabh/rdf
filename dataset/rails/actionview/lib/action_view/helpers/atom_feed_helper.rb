require 'set'

module ActionView
  module Helpers
    module AtomFeedHelper
      def atom_feed(options = {}, &block)
        if options[:schema_date]
          options[:schema_date] = options[:schema_date].strftime("%Y-%m-%d") if options[:schema_date].respond_to?(:strftime)
        else
          options[:schema_date] = "2005" # The Atom spec copyright date
        end

        #nodyna <eval-1225> <EV COMPLEX (scope)>
        xml = options.delete(:xml) || eval("xml", block.binding)
        xml.instruct!
        if options[:instruct]
          options[:instruct].each do |target,attrs|
            if attrs.respond_to?(:keys)
              xml.instruct!(target, attrs)
            elsif attrs.respond_to?(:each)
              attrs.each { |attr_group| xml.instruct!(target, attr_group) }
            end
          end
        end

        feed_opts = {"xml:lang" => options[:language] || "en-US", "xmlns" => 'http://www.w3.org/2005/Atom'}
        feed_opts.merge!(options).reject!{|k,v| !k.to_s.match(/^xml/)}

        xml.feed(feed_opts) do
          xml.id(options[:id] || "tag:#{request.host},#{options[:schema_date]}:#{request.fullpath.split(".")[0]}")
          xml.link(:rel => 'alternate', :type => 'text/html', :href => options[:root_url] || (request.protocol + request.host_with_port))
          xml.link(:rel => 'self', :type => 'application/atom+xml', :href => options[:url] || request.url)

          yield AtomFeedBuilder.new(xml, self, options)
        end
      end

      class AtomBuilder #:nodoc:
        XHTML_TAG_NAMES = %w(content rights title subtitle summary).to_set

        def initialize(xml)
          @xml = xml
        end

        private
          def method_missing(method, *arguments, &block)
            if xhtml_block?(method, arguments)
              @xml.__send__(method, *arguments) do
                @xml.div(:xmlns => 'http://www.w3.org/1999/xhtml') do |xhtml|
                  block.call(xhtml)
                end
              end
            else
              @xml.__send__(method, *arguments, &block)
            end
          end

          def xhtml_block?(method, arguments)
            if XHTML_TAG_NAMES.include?(method.to_s)
              last = arguments.last
              last.is_a?(Hash) && last[:type].to_s == 'xhtml'
            end
          end
      end

      class AtomFeedBuilder < AtomBuilder #:nodoc:
        def initialize(xml, view, feed_options = {})
          @xml, @view, @feed_options = xml, view, feed_options
        end

        def updated(date_or_time = nil)
          @xml.updated((date_or_time || Time.now.utc).xmlschema)
        end

        def entry(record, options = {})
          @xml.entry do
            @xml.id(options[:id] || "tag:#{@view.request.host},#{@feed_options[:schema_date]}:#{record.class}/#{record.id}")

            if options[:published] || (record.respond_to?(:created_at) && record.created_at)
              @xml.published((options[:published] || record.created_at).xmlschema)
            end

            if options[:updated] || (record.respond_to?(:updated_at) && record.updated_at)
              @xml.updated((options[:updated] || record.updated_at).xmlschema)
            end

            type = options.fetch(:type, 'text/html')

            @xml.link(:rel => 'alternate', :type => type, :href => options[:url] || @view.polymorphic_url(record))

            yield AtomBuilder.new(@xml)
          end
        end
      end

    end
  end
end
