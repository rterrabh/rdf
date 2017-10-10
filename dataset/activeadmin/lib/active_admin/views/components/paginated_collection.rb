require 'active_admin/helpers/collection'

module ActiveAdmin
  module Views

    class PaginatedCollection < ActiveAdmin::Component
      builder_method :paginated_collection

      attr_reader :collection

      def build(collection, options = {})
        @collection     = collection
        @param_name     = options.delete(:param_name)
        @download_links = options.delete(:download_links)
        @display_total  = options.delete(:pagination_total) { true }
        @per_page       = options.delete(:per_page)

        unless collection.respond_to?(:num_pages)
          raise(StandardError, "Collection is not a paginated scope. Set collection.page(params[:page]).per(10) before calling :paginated_collection.")
        end

        @contents = div(class: "paginated_collection_contents")
        build_pagination_with_formats(options)
        @built = true
      end

      def add_child(*args, &block)
        if @built
          @contents.add_child(*args, &block)
        else
          super
        end
      end

      protected

      def build_pagination_with_formats(options)
        div id: "index_footer" do
          build_per_page_select if @per_page.is_a?(Array)
          build_pagination
          div(page_entries_info(options).html_safe, class: "pagination_information")

          #nodyna <instance_exec-54> <IEX COMPLEX (block without parameters)>
          download_links = @download_links.is_a?(Proc) ? instance_exec(&@download_links) : @download_links

          if download_links.is_a?(Array) && !download_links.empty?
            build_download_format_links download_links
          else
            build_download_format_links unless download_links == false
          end
        end
      end

      def build_per_page_select
        div class: "pagination_per_page" do
          text_node "Per page:"
          select do
            @per_page.each do |per_page|
              option(
                per_page,
                value: per_page,
                selected: collection.limit_value == per_page ? "selected" : nil
              )
            end
          end
        end
      end

      def build_pagination
        options = {}
        options[:param_name] = @param_name if @param_name

        text_node paginate collection, options
      end

      include ::ActiveAdmin::Helpers::Collection
      include ::ActiveAdmin::ViewHelpers::DownloadFormatLinksHelper

      def page_entries_info(options = {})
        if options[:entry_name]
          entry_name   = options[:entry_name]
          entries_name = options[:entries_name] || entry_name.pluralize
        elsif collection_is_empty?
          entry_name   = I18n.t "active_admin.pagination.entry", count: 1, default: 'entry'
          entries_name = I18n.t "active_admin.pagination.entry", count: 2, default: 'entries'
        else
          key = "activerecord.models." + collection.first.class.model_name.i18n_key.to_s
          entry_name   = I18n.translate key, count: 1,               default: collection.first.class.name.underscore.sub('_', ' ')
          entries_name = I18n.translate key, count: collection.size, default: entry_name.pluralize
        end

        if collection.num_pages < 2
          case collection_size
          when 0; I18n.t('active_admin.pagination.empty',    model: entries_name)
          when 1; I18n.t('active_admin.pagination.one',      model: entry_name)
          else;   I18n.t('active_admin.pagination.one_page', model: entries_name, n: collection.total_count)
          end
        else
          offset = (collection.current_page - 1) * collection.limit_value
          if @display_total
            total  = collection.total_count
            I18n.t 'active_admin.pagination.multiple', model: entries_name, total: total,
              from: offset + 1, to: offset + collection_size
          else
            I18n.t 'active_admin.pagination.multiple_without_total', model: entries_name,
              from: offset + 1, to: offset + collection_size
          end
        end
      end

    end
  end
end
