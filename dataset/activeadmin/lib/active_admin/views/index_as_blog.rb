module ActiveAdmin
  module Views

    class IndexAsBlog < ActiveAdmin::Component

      def build(page_presenter, collection)
        @page_presenter = page_presenter
        @collection = collection

        #nodyna <instance_exec-61> <IEX COMPLEX (block without parameters)>
        instance_exec &page_presenter.block if page_presenter.block

        add_class "index"
        build_posts
      end

      def title(method = nil, &block)
        if block_given? || method
          @title = block_given? ? block : method
        end
        @title
      end


      def body(method = nil, &block)
        if block_given? || method
          @body = block_given? ? block : method
        end
        @body
      end

      def self.index_name
        "blog"
      end

      private

      def build_posts
        resource_selection_toggle_panel if active_admin_config.batch_actions.any?
        @collection.each do |post|
          build_post(post)
        end
      end

      def build_post(post)
        div for: post do
          resource_selection_cell(post) if active_admin_config.batch_actions.any?
          build_title(post)
          build_body(post)
        end
      end

      def build_title(post)
        if @title
          h3 do
            a(href: resource_path(post)) do
             render_method_on_post_or_call_proc post, @title
            end
          end
        else
          h3 do
            auto_link(post)
          end
        end
      end

      def build_body(post)
        if @body
          div class: 'content' do
            render_method_on_post_or_call_proc post, @body
          end
        end
      end

      def render_method_on_post_or_call_proc(post, proc)
        case proc
        when String, Symbol
          #nodyna <send-62> <SD COMPLEX (change-prone variables)>
          post.public_send proc
        else
          #nodyna <instance_exec-63> <IEX COMPLEX (block with parameters)>
          instance_exec post, &proc
        end
      end

    end # Posts
  end
end
