require 'thread_safe'

module ActionView
  class PartialIteration
    attr_reader :size

    attr_reader :index

    def initialize(size)
      @size  = size
      @index = 0
    end

    def first?
      index == 0
    end

    def last?
      index == size - 1
    end

    def iterate! # :nodoc:
      @index += 1
    end
  end

  class PartialRenderer < AbstractRenderer
    PREFIXED_PARTIAL_NAMES = ThreadSafe::Cache.new do |h, k|
      h[k] = ThreadSafe::Cache.new
    end

    def initialize(*)
      super
      @context_prefix = @lookup_context.prefixes.first
    end

    def render(context, options, block)
      setup(context, options, block)
      identifier = (@template = find_partial) ? @template.identifier : @path

      @lookup_context.rendered_format ||= begin
        if @template && @template.formats.present?
          @template.formats.first
        else
          formats.first
        end
      end

      if @collection
        instrument(:collection, :identifier => identifier || "collection", :count => @collection.size) do
          render_collection
        end
      else
        instrument(:partial, :identifier => identifier) do
          render_partial
        end
      end
    end

    private

    def render_collection
      return nil if @collection.blank?

      if @options.key?(:spacer_template)
        spacer = find_template(@options[:spacer_template], @locals.keys).render(@view, @locals)
      end

      result = @template ? collection_with_template : collection_without_template
      result.join(spacer).html_safe
    end

    def render_partial
      view, locals, block = @view, @locals, @block
      object, as = @object, @variable

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s, @template_keys)
      end

      object ||= locals[as]
      locals[as] = object

      content = @template.render(view, locals) do |*name|
        view._layout_for(*name, &block)
      end

      content = layout.render(view, locals){ content } if layout
      content
    end

    private

    def setup(context, options, block)
      @view   = context
      @options = options
      @block   = block

      @locals  = options[:locals] || {}
      @details = extract_details(options)

      prepend_formats(options[:formats])

      partial = options[:partial]

      if String === partial
        @has_object = options.key?(:object)
        @object     = options[:object]
        @collection = collection_from_options
        @path       = partial
      else
        @has_object = true
        @object = partial
        @collection = collection_from_object || collection_from_options

        if @collection
          paths = @collection_data = @collection.map { |o| partial_path(o) }
          @path = paths.uniq.one? ? paths.first : nil
        else
          @path = partial_path
        end
      end

      if as = options[:as]
        raise_invalid_option_as(as) unless as.to_s =~ /\A[a-z_]\w*\z/
        as = as.to_sym
      end

      if @path
        @variable, @variable_counter, @variable_iteration = retrieve_variable(@path, as)
        @template_keys = retrieve_template_keys
      else
        paths.map! { |path| retrieve_variable(path, as).unshift(path) }
      end

      self
    end

    def collection_from_options
      if @options.key?(:collection)
        collection = @options[:collection]
        collection.respond_to?(:to_ary) ? collection.to_ary : []
      end
    end

    def collection_from_object
      @object.to_ary if @object.respond_to?(:to_ary)
    end

    def find_partial
      find_template(@path, @template_keys) if @path
    end

    def find_template(path, locals)
      prefixes = path.include?(?/) ? [] : @lookup_context.prefixes
      @lookup_context.find_template(path, prefixes, true, locals, @details)
    end

    def collection_with_template
      view, locals, template = @view, @locals, @template
      as, counter, iteration = @variable, @variable_counter, @variable_iteration

      if layout = @options[:layout]
        layout = find_template(layout, @template_keys)
      end

      partial_iteration = PartialIteration.new(@collection.size)
      locals[iteration] = partial_iteration

      @collection.map do |object|
        locals[as]        = object
        locals[counter]   = partial_iteration.index

        content = template.render(view, locals)
        content = layout.render(view, locals) { content } if layout
        partial_iteration.iterate!
        content
      end
    end

    def collection_without_template
      view, locals, collection_data = @view, @locals, @collection_data
      cache = {}
      keys  = @locals.keys

      partial_iteration = PartialIteration.new(@collection.size)

      @collection.map do |object|
        index = partial_iteration.index
        path, as, counter, iteration = collection_data[index]

        locals[as]        = object
        locals[counter]   = index
        locals[iteration] = partial_iteration

        template = (cache[path] ||= find_template(path, keys + [as, counter]))
        content = template.render(view, locals)
        partial_iteration.iterate!
        content
      end
    end

    def partial_path(object = @object)
      object = object.to_model if object.respond_to?(:to_model)

      path = if object.respond_to?(:to_partial_path)
        object.to_partial_path
      else
        raise ArgumentError.new("'#{object.inspect}' is not an ActiveModel-compatible object. It must implement :to_partial_path.")
      end

      if @view.prefix_partial_path_with_controller_namespace
        prefixed_partial_names[path] ||= merge_prefix_into_object_path(@context_prefix, path.dup)
      else
        path
      end
    end

    def prefixed_partial_names
      @prefixed_partial_names ||= PREFIXED_PARTIAL_NAMES[@context_prefix]
    end

    def merge_prefix_into_object_path(prefix, object_path)
      if prefix.include?(?/) && object_path.include?(?/)
        prefixes = []
        prefix_array = File.dirname(prefix).split('/')
        object_path_array = object_path.split('/')[0..-3] # skip model dir & partial

        prefix_array.each_with_index do |dir, index|
          break if dir == object_path_array[index]
          prefixes << dir
        end

        (prefixes << object_path).join("/")
      else
        object_path
      end
    end

    def retrieve_template_keys
      keys = @locals.keys
      keys << @variable if @has_object || @collection
      if @collection
        keys << @variable_counter
        keys << @variable_iteration
      end
      keys
    end

    def retrieve_variable(path, as)
      variable = as || begin
        base = path[-1] == "/" ? "" : File.basename(path)
        raise_invalid_identifier(path) unless base =~ /\A_?([a-z]\w*)(\.\w+)*\z/
        $1.to_sym
      end
      if @collection
        variable_counter = :"#{variable}_counter"
        variable_iteration = :"#{variable}_iteration"
      end
      [variable, variable_counter, variable_iteration]
    end

    IDENTIFIER_ERROR_MESSAGE = "The partial name (%s) is not a valid Ruby identifier; " +
                               "make sure your partial name starts with underscore, " +
                               "and is followed by any combination of letters, numbers and underscores."

    OPTION_AS_ERROR_MESSAGE  = "The value (%s) of the option `as` is not a valid Ruby identifier; " +
                               "make sure it starts with lowercase letter, " +
                               "and is followed by any combination of letters, numbers and underscores."

    def raise_invalid_identifier(path)
      raise ArgumentError.new(IDENTIFIER_ERROR_MESSAGE % (path))
    end

    def raise_invalid_option_as(as)
      raise ArgumentError.new(OPTION_AS_ERROR_MESSAGE % (as))
    end
  end
end
