require 'active_admin/view_helpers/method_or_proc_helper'

module ActiveAdmin
  class MenuItem
    include Menu::MenuNode
    include MethodOrProcHelper

    attr_reader :html_options, :parent, :priority

    def initialize(options = {})
      super() # MenuNode
      @label          = options[:label]
      @dirty_id       = options[:id]           || options[:label]
      @url            = options[:url]          || '#'
      @priority       = options[:priority]     || 10
      @html_options   = options[:html_options] || {}
      @should_display = options[:if]           || proc{true}
      @parent         = options[:parent]

      yield(self) if block_given? # Builder style syntax
    end

    def id
      @id ||= normalize_id @dirty_id
    end

    def label(context = nil)
      render_in_context context, @label
    end

    def url(context = nil)
      render_in_context context, @url
    end

    def display?(context = nil)
      return false unless render_in_context(context, @should_display)
      return false if     !real_url?(context) && @children.any? && !items(context).any?
      true
    end

    def ancestors
      parent ? [parent, parent.ancestors].flatten : []
    end

    private

    def real_url?(context = nil)
      url = url context
      url.present? && url != '#'
    end

  end
end
