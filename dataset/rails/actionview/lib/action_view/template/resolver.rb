require "pathname"
require "active_support/core_ext/class"
require "active_support/core_ext/module/attribute_accessors"
require 'active_support/core_ext/string/filters'
require "action_view/template"
require "thread"
require "thread_safe"

module ActionView
  class Resolver
    class Path
      attr_reader :name, :prefix, :partial, :virtual
      alias_method :partial?, :partial

      def self.build(name, prefix, partial)
        virtual = ""
        virtual << "#{prefix}/" unless prefix.empty?
        virtual << (partial ? "_#{name}" : name)
        new name, prefix, partial, virtual
      end

      def initialize(name, prefix, partial, virtual)
        @name    = name
        @prefix  = prefix
        @partial = partial
        @virtual = virtual
      end

      def to_str
        @virtual
      end
      alias :to_s :to_str
    end

    class Cache #:nodoc:
      class SmallCache < ThreadSafe::Cache
        def initialize(options = {})
          super(options.merge(:initial_capacity => 2))
        end
      end

      PARTIAL_BLOCK = lambda {|cache, partial| cache[partial] = SmallCache.new}
      PREFIX_BLOCK  = lambda {|cache, prefix|  cache[prefix]  = SmallCache.new(&PARTIAL_BLOCK)}
      NAME_BLOCK    = lambda {|cache, name|    cache[name]    = SmallCache.new(&PREFIX_BLOCK)}
      KEY_BLOCK     = lambda {|cache, key|     cache[key]     = SmallCache.new(&NAME_BLOCK)}

      NO_TEMPLATES = [].freeze

      def initialize
        @data = SmallCache.new(&KEY_BLOCK)
      end

      def cache(key, name, prefix, partial, locals)
        if Resolver.caching?
          @data[key][name][prefix][partial][locals] ||= canonical_no_templates(yield)
        else
          fresh_templates  = yield
          cached_templates = @data[key][name][prefix][partial][locals]

          if templates_have_changed?(cached_templates, fresh_templates)
            @data[key][name][prefix][partial][locals] = canonical_no_templates(fresh_templates)
          else
            cached_templates || NO_TEMPLATES
          end
        end
      end

      def clear
        @data.clear
      end

      private

      def canonical_no_templates(templates)
        templates.empty? ? NO_TEMPLATES : templates
      end

      def templates_have_changed?(cached_templates, fresh_templates)
        if cached_templates.blank? || fresh_templates.blank?
          return fresh_templates.blank? != cached_templates.blank?
        end

        cached_templates_max_updated_at = cached_templates.map(&:updated_at).max

        fresh_templates.any? { |t| t.updated_at > cached_templates_max_updated_at }
      end
    end

    cattr_accessor :caching
    self.caching = true

    class << self
      alias :caching? :caching
    end

    def initialize
      @cache = Cache.new
    end

    def clear_cache
      @cache.clear
    end

    def find_all(name, prefix=nil, partial=false, details={}, key=nil, locals=[])
      cached(key, [name, prefix, partial], details, locals) do
        find_templates(name, prefix, partial, details)
      end
    end

  private

    delegate :caching?, to: :class

    def find_templates(name, prefix, partial, details)
      raise NotImplementedError, "Subclasses must implement a find_templates(name, prefix, partial, details) method"
    end

    def build_path(name, prefix, partial)
      Path.build(name, prefix, partial)
    end

    def cached(key, path_info, details, locals) #:nodoc:
      name, prefix, partial = path_info
      locals = locals.map { |x| x.to_s }.sort!

      if key
        @cache.cache(key, name, prefix, partial, locals) do
          decorate(yield, path_info, details, locals)
        end
      else
        decorate(yield, path_info, details, locals)
      end
    end

    def decorate(templates, path_info, details, locals) #:nodoc:
      cached = nil
      templates.each do |t|
        t.locals         = locals
        t.formats        = details[:formats]  || [:html] if t.formats.empty?
        t.variants       = details[:variants] || []      if t.variants.empty?
        t.virtual_path ||= (cached ||= build_path(*path_info))
      end
    end
  end

  class PathResolver < Resolver #:nodoc:
    EXTENSIONS = { :locale => ".", :formats => ".", :variants => "+", :handlers => "." }
    DEFAULT_PATTERN = ":prefix/:action{.:locale,}{.:formats,}{+:variants,}{.:handlers,}"

    def initialize(pattern=nil)
      @pattern = pattern || DEFAULT_PATTERN
      super()
    end

    private

    def find_templates(name, prefix, partial, details)
      path = Path.build(name, prefix, partial)
      query(path, details, details[:formats])
    end

    def query(path, details, formats)
      query = build_query(path, details)

      template_paths = find_template_paths query

      template_paths.map { |template|
        handler, format, variant = extract_handler_and_format_and_variant(template, formats)
        contents = File.binread(template)

        Template.new(contents, File.expand_path(template), handler,
          :virtual_path => path.virtual,
          :format       => format,
          :variant      => variant,
          :updated_at   => mtime(template)
        )
      }
    end

    if RUBY_VERSION >= '2.2.0'
      def find_template_paths(query)
        Dir[query].reject { |filename|
          File.directory?(filename) ||
            !File.fnmatch(query, filename, File::FNM_EXTGLOB)
        }
      end
    else
      def find_template_paths(query)
        sanitizer = Hash.new { |h,dir| h[dir] = Dir["#{dir}/*"] }

        Dir[query].reject { |filename|
          File.directory?(filename) ||
            !sanitizer[File.dirname(filename)].include?(filename)
        }
      end
    end

    def build_query(path, details)
      query = @pattern.dup

      prefix = path.prefix.empty? ? "" : "#{escape_entry(path.prefix)}\\1"
      query.gsub!(/\:prefix(\/)?/, prefix)

      partial = escape_entry(path.partial? ? "_#{path.name}" : path.name)
      query.gsub!(/\:action/, partial)

      details.each do |ext, variants|
        query.gsub!(/\:#{ext}/, "{#{variants.compact.uniq.join(',')}}")
      end

      File.expand_path(query, @path)
    end

    def escape_entry(entry)
      entry.gsub(/[*?{}\[\]]/, '\\\\\\&')
    end

    def mtime(p)
      File.mtime(p)
    end

    def extract_handler_and_format_and_variant(path, default_formats)
      pieces = File.basename(path).split(".")
      pieces.shift

      extension = pieces.pop
      unless extension
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          The file #{path} did not specify a template handler. The default is
          currently ERB, but will change to RAW in the future.
        MSG
      end

      handler = Template.handler_for_extension(extension)
      format, variant = pieces.last.split(EXTENSIONS[:variants], 2) if pieces.last
      format  &&= Template::Types[format]

      [handler, format, variant]
    end
  end

  class FileSystemResolver < PathResolver
    def initialize(path, pattern=nil)
      raise ArgumentError, "path already is a Resolver class" if path.is_a?(Resolver)
      super(pattern)
      @path = File.expand_path(path)
    end

    def to_s
      @path.to_s
    end
    alias :to_path :to_s

    def eql?(resolver)
      self.class.equal?(resolver.class) && to_path == resolver.to_path
    end
    alias :== :eql?
  end

  class OptimizedFileSystemResolver < FileSystemResolver #:nodoc:
    def build_query(path, details)
      query = escape_entry(File.join(@path, path))

      exts = EXTENSIONS.map do |ext, prefix|
        "{#{details[ext].compact.uniq.map { |e| "#{prefix}#{e}," }.join}}"
      end.join

      query + exts
    end
  end

  class FallbackFileSystemResolver < FileSystemResolver #:nodoc:
    def self.instances
      [new(""), new("/")]
    end

    def decorate(*)
      super.each { |t| t.virtual_path = nil }
    end
  end
end
