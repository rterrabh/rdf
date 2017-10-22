require 'rake/cloneable'
require 'rake/file_utils_ext'
require 'rake/pathmap'


module Rake

  class FileList

    include Cloneable


    ARRAY_METHODS = (Array.instance_methods - Object.instance_methods).
      map { |n| n.to_s }

    MUST_DEFINE = %w[inspect <=>]

    MUST_NOT_DEFINE = %w[to_a to_ary partition * <<]

    SPECIAL_RETURN = %w[
      map collect sort sort_by select find_all reject grep
      compact flatten uniq values_at
      + - & |
    ]

    DELEGATING_METHODS = (ARRAY_METHODS + MUST_DEFINE - MUST_NOT_DEFINE).
      map { |s| s.to_s }.sort.uniq

    DELEGATING_METHODS.each do |sym|
      if SPECIAL_RETURN.include?(sym)
        ln = __LINE__ + 1
        #nodyna <class_eval-2036> <CE MODERATE (define methods)>
        class_eval %{
          def #{sym}(*args, &block)
            resolve
            #nodyna <send-2039> <SD MODERATE (change-prone variables)>
            result = @items.send(:#{sym}, *args, &block)
            FileList.new.import(result)
          end
        }, __FILE__, ln
      else
        ln = __LINE__ + 1
        #nodyna <class_eval-2038> <CE MODERATE (define methods)>
        class_eval %{
          def #{sym}(*args, &block)
            resolve
            #nodyna <send-2039> <SD MODERATE (change-prone variables)>
            result = @items.send(:#{sym}, *args, &block)
            result.object_id == @items.object_id ? self : result
          end
        }, __FILE__, ln
      end
    end

    def initialize(*patterns)
      @pending_add = []
      @pending = false
      @exclude_patterns = DEFAULT_IGNORE_PATTERNS.dup
      @exclude_procs = DEFAULT_IGNORE_PROCS.dup
      @items = []
      patterns.each { |pattern| include(pattern) }
      yield self if block_given?
    end

    def include(*filenames)
      filenames.each do |fn|
        if fn.respond_to? :to_ary
          include(*fn.to_ary)
        else
          @pending_add << Rake.from_pathname(fn)
        end
      end
      @pending = true
      self
    end
    alias :add :include

    def exclude(*patterns, &block)
      patterns.each do |pat|
        @exclude_patterns << Rake.from_pathname(pat)
      end
      @exclude_procs << block if block_given?
      resolve_exclude unless @pending
      self
    end

    def clear_exclude
      @exclude_patterns = []
      @exclude_procs = []
      self
    end

    def ==(array)
      to_ary == array
    end

    def to_a
      resolve
      @items
    end

    def to_ary
      to_a
    end

    def is_a?(klass)
      klass == Array || super(klass)
    end
    alias kind_of? is_a?

    def *(other)
      result = @items * other
      case result
      when Array
        FileList.new.import(result)
      else
        result
      end
    end

    def <<(obj)
      resolve
      @items << Rake.from_pathname(obj)
      self
    end

    def resolve
      if @pending
        @pending = false
        @pending_add.each do |fn| resolve_add(fn) end
        @pending_add = []
        resolve_exclude
      end
      self
    end

    def resolve_add(fn) # :nodoc:
      case fn
      when %r{[*?\[\{]}
        add_matching(fn)
      else
        self << fn
      end
    end
    private :resolve_add

    def resolve_exclude # :nodoc:
      reject! { |fn| excluded_from_list?(fn) }
      self
    end
    private :resolve_exclude

    def sub(pat, rep)
      inject(FileList.new) { |res, fn| res << fn.sub(pat, rep) }
    end

    def gsub(pat, rep)
      inject(FileList.new) { |res, fn| res << fn.gsub(pat, rep) }
    end

    def sub!(pat, rep)
      each_with_index { |fn, i| self[i] = fn.sub(pat, rep) }
      self
    end

    def gsub!(pat, rep)
      each_with_index { |fn, i| self[i] = fn.gsub(pat, rep) }
      self
    end

    def pathmap(spec=nil)
      collect { |fn| fn.pathmap(spec) }
    end

    def ext(newext='')
      collect { |fn| fn.ext(newext) }
    end

    def egrep(pattern, *options)
      matched = 0
      each do |fn|
        begin
          open(fn, "r", *options) do |inf|
            count = 0
            inf.each do |line|
              count += 1
              if pattern.match(line)
                matched += 1
                if block_given?
                  yield fn, count, line
                else
                  puts "#{fn}:#{count}:#{line}"
                end
              end
            end
          end
        rescue StandardError => ex
          $stderr.puts "Error while processing '#{fn}': #{ex}"
        end
      end
      matched
    end

    def existing
      select { |fn| File.exist?(fn) }
    end

    def existing!
      resolve
      @items = @items.select { |fn| File.exist?(fn) }
      self
    end

    def partition(&block)       # :nodoc:
      resolve
      result = @items.partition(&block)
      [
        FileList.new.import(result[0]),
        FileList.new.import(result[1]),
      ]
    end

    def to_s
      resolve
      self.join(' ')
    end

    def add_matching(pattern)
      FileList.glob(pattern).each do |fn|
        self << fn unless excluded_from_list?(fn)
      end
    end
    private :add_matching

    def excluded_from_list?(fn)
      return true if @exclude_patterns.any? do |pat|
        case pat
        when Regexp
          fn =~ pat
        when /[*?]/
          File.fnmatch?(pat, fn, File::FNM_PATHNAME)
        else
          fn == pat
        end
      end
      @exclude_procs.any? { |p| p.call(fn) }
    end

    DEFAULT_IGNORE_PATTERNS = [
      /(^|[\/\\])CVS([\/\\]|$)/,
      /(^|[\/\\])\.svn([\/\\]|$)/,
      /\.bak$/,
      /~$/
    ]
    DEFAULT_IGNORE_PROCS = [
      proc { |fn| fn =~ /(^|[\/\\])core$/ && ! File.directory?(fn) }
    ]

    def import(array) # :nodoc:
      @items = array
      self
    end

    class << self
      def [](*args)
        new(*args)
      end

      def glob(pattern, *args)
        Dir.glob(pattern, *args).sort
      end
    end
  end
end

module Rake
  class << self

    def each_dir_parent(dir)    # :nodoc:
      old_length = nil
      while dir != '.' && dir.length != old_length
        yield(dir)
        old_length = dir.length
        dir = File.dirname(dir)
      end
    end

    def from_pathname(path)    # :nodoc:
      path = path.to_path if path.respond_to?(:to_path)
      path = path.to_str if path.respond_to?(:to_str)
      path
    end
  end
end # module Rake
