require 'set'
require 'thread'
require 'thread_safe'
require 'pathname'
require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/module/qualified_const'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/load_error'
require 'active_support/core_ext/name_error'
require 'active_support/core_ext/string/starts_ends_with'
require 'active_support/inflector'

module ActiveSupport #:nodoc:
  module Dependencies #:nodoc:
    extend self

    mattr_accessor :warnings_on_first_load
    self.warnings_on_first_load = false

    mattr_accessor :history
    self.history = Set.new

    mattr_accessor :loaded
    self.loaded = Set.new

    mattr_accessor :loading
    self.loading = []

    mattr_accessor :mechanism
    self.mechanism = ENV['NO_RELOAD'] ? :require : :load

    mattr_accessor :autoload_paths
    self.autoload_paths = []

    mattr_accessor :autoload_once_paths
    self.autoload_once_paths = []

    mattr_accessor :autoloaded_constants
    self.autoloaded_constants = []

    mattr_accessor :explicitly_unloadable_constants
    self.explicitly_unloadable_constants = []

    mattr_accessor :logger

    mattr_accessor :log_activity
    self.log_activity = false

    class WatchStack
      include Enumerable


      def initialize
        @watching = []
        @stack = Hash.new { |h,k| h[k] = [] }
      end

      def each(&block)
        @stack.each(&block)
      end

      def watching?
        !@watching.empty?
      end

      def new_constants
        constants = []

        @watching.last.each do |namespace|
          original_constants = @stack[namespace].last

          mod = Inflector.constantize(namespace) if Dependencies.qualified_const_defined?(namespace)
          next unless mod.is_a?(Module)

          new_constants = mod.local_constants - original_constants

          @stack[namespace].each do |namespace_constants|
            namespace_constants.concat(new_constants)
          end

          new_constants.each do |suffix|
            constants << ([namespace, suffix] - ["Object"]).join("::")
          end
        end
        constants
      ensure
        pop_modules(@watching.pop)
      end

      def watch_namespaces(namespaces)
        @watching << namespaces.map do |namespace|
          module_name = Dependencies.to_constant_name(namespace)
          original_constants = Dependencies.qualified_const_defined?(module_name) ?
            Inflector.constantize(module_name).local_constants : []

          @stack[module_name] << original_constants
          module_name
        end
      end

      private
      def pop_modules(modules)
        modules.each { |mod| @stack[mod].pop }
      end
    end

    mattr_accessor :constant_watch_stack
    self.constant_watch_stack = WatchStack.new

    module ModuleConstMissing #:nodoc:
      def self.append_features(base)
        #nodyna <class_eval-1110> <CE COMPLEX (block execution)>
        base.class_eval do
          return if defined?(@_const_missing) && @_const_missing
          @_const_missing = instance_method(:const_missing)
          remove_method(:const_missing)
        end
        super
      end

      def self.exclude_from(base)
        #nodyna <class_eval-1111> <CE COMPLEX (block execution)>
        base.class_eval do
          #nodyna <define_method-1112> <DM MODERATE (events)>
          define_method :const_missing, @_const_missing
          @_const_missing = nil
        end
      end

      def const_missing(const_name)
        from_mod = anonymous? ? guess_for_anonymous(const_name) : self
        Dependencies.load_missing_constant(from_mod, const_name)
      end

      def guess_for_anonymous(const_name)
        if Object.const_defined?(const_name)
          raise NameError.new "#{const_name} cannot be autoloaded from an anonymous class or module", const_name
        else
          Object
        end
      end

      def unloadable(const_desc = self)
        super(const_desc)
      end
    end

    module Loadable #:nodoc:
      def self.exclude_from(base)
        #nodyna <class_eval-1113> <CE COMPLEX (block execution)>
        base.class_eval do
          #nodyna <define_method-1114> <DM MODERATE (events)>
          define_method(:load, Kernel.instance_method(:load))
          private :load
        end
      end

      def require_or_load(file_name)
        Dependencies.require_or_load(file_name)
      end

      def require_dependency(file_name, message = "No such file to load -- %s")
        file_name = file_name.to_path if file_name.respond_to?(:to_path)
        unless file_name.is_a?(String)
          raise ArgumentError, "the file name must either be a String or implement #to_path -- you passed #{file_name.inspect}"
        end

        Dependencies.depend_on(file_name, message)
      end

      def load_dependency(file)
        if Dependencies.load? && ActiveSupport::Dependencies.constant_watch_stack.watching?
          Dependencies.new_constants_in(Object) { yield }
        else
          yield
        end
      rescue Exception => exception  # errors from loading file
        exception.blame_file! file if exception.respond_to? :blame_file!
        raise
      end

      def unloadable(const_desc)
        Dependencies.mark_for_unload const_desc
      end

      private

      def load(file, wrap = false)
        result = false
        load_dependency(file) { result = super }
        result
      end

      def require(file)
        result = false
        load_dependency(file) { result = super }
        result
      end
    end

    module Blamable #:nodoc:
      def blame_file!(file)
        (@blamed_files ||= []).unshift file
      end

      def blamed_files
        @blamed_files ||= []
      end

      def describe_blame
        return nil if blamed_files.empty?
        "This error occurred while loading the following files:\n   #{blamed_files.join "\n   "}"
      end

      def copy_blame!(exc)
        @blamed_files = exc.blamed_files.clone
        self
      end
    end

    def hook!
      #nodyna <class_eval-1115> <CE TRIVIAL (block execution)>
      Object.class_eval { include Loadable }
      #nodyna <class_eval-1116> <CE TRIVIAL (block execution)>
      Module.class_eval { include ModuleConstMissing }
      #nodyna <class_eval-1117> <CE TRIVIAL (block execution)>
      Exception.class_eval { include Blamable }
    end

    def unhook!
      ModuleConstMissing.exclude_from(Module)
      Loadable.exclude_from(Object)
    end

    def load?
      mechanism == :load
    end

    def depend_on(file_name, message = "No such file to load -- %s.rb")
      path = search_for_file(file_name)
      require_or_load(path || file_name)
    rescue LoadError => load_error
      if file_name = load_error.message[/ -- (.*?)(\.rb)?$/, 1]
        load_error.message.replace(message % file_name)
        load_error.copy_blame!(load_error)
      end
      raise
    end

    def clear
      log_call
      loaded.clear
      loading.clear
      remove_unloadable_constants!
    end

    def require_or_load(file_name, const_path = nil)
      log_call file_name, const_path
      file_name = $` if file_name =~ /\.rb\z/
      expanded = File.expand_path(file_name)
      return if loaded.include?(expanded)

      loaded << expanded
      loading << expanded

      begin
        if load?
          log "loading #{file_name}"

          load_args = ["#{file_name}.rb"]
          load_args << const_path unless const_path.nil?

          if !warnings_on_first_load or history.include?(expanded)
            result = load_file(*load_args)
          else
            enable_warnings { result = load_file(*load_args) }
          end
        else
          log "requiring #{file_name}"
          result = require file_name
        end
      rescue Exception
        loaded.delete expanded
        raise
      ensure
        loading.pop
      end

      history << expanded
      result
    end

    def qualified_const_defined?(path)
      Object.qualified_const_defined?(path.sub(/^::/, ''), false)
    end

    def loadable_constants_for_path(path, bases = autoload_paths)
      path = $` if path =~ /\.rb\z/
      expanded_path = File.expand_path(path)
      paths = []

      bases.each do |root|
        expanded_root = File.expand_path(root)
        next unless %r{\A#{Regexp.escape(expanded_root)}(/|\\)} =~ expanded_path

        nesting = expanded_path[(expanded_root.size)..-1]
        nesting = nesting[1..-1] if nesting && nesting[0] == ?/
        next if nesting.blank?

        paths << nesting.camelize
      end

      paths.uniq!
      paths
    end

    def search_for_file(path_suffix)
      path_suffix = path_suffix.sub(/(\.rb)?$/, ".rb")

      autoload_paths.each do |root|
        path = File.join(root, path_suffix)
        return path if File.file? path
      end
      nil # Gee, I sure wish we had first_match ;-)
    end

    def autoloadable_module?(path_suffix)
      autoload_paths.each do |load_path|
        return load_path if File.directory? File.join(load_path, path_suffix)
      end
      nil
    end

    def load_once_path?(path)
      autoload_once_paths.any? { |base| path.starts_with? base.to_s }
    end

    def autoload_module!(into, const_name, qualified_name, path_suffix)
      return nil unless base_path = autoloadable_module?(path_suffix)
      mod = Module.new
      #nodyna <const_set-1118> <CS MODERATE (change-prone variable)>
      into.const_set const_name, mod
      autoloaded_constants << qualified_name unless autoload_once_paths.include?(base_path)
      mod
    end

    def load_file(path, const_paths = loadable_constants_for_path(path))
      log_call path, const_paths
      const_paths = [const_paths].compact unless const_paths.is_a? Array
      parent_paths = const_paths.collect { |const_path| const_path[/.*(?=::)/] || ::Object }

      result = nil
      newly_defined_paths = new_constants_in(*parent_paths) do
        result = Kernel.load path
      end

      autoloaded_constants.concat newly_defined_paths unless load_once_path?(path)
      autoloaded_constants.uniq!
      log "loading #{path} defined #{newly_defined_paths * ', '}" unless newly_defined_paths.empty?
      result
    end

    def qualified_name_for(mod, name)
      mod_name = to_constant_name mod
      mod_name == "Object" ? name.to_s : "#{mod_name}::#{name}"
    end

    def load_missing_constant(from_mod, const_name)
      log_call from_mod, const_name

      unless qualified_const_defined?(from_mod.name) && Inflector.constantize(from_mod.name).equal?(from_mod)
        raise ArgumentError, "A copy of #{from_mod} has been removed from the module tree but is still active!"
      end

      qualified_name = qualified_name_for from_mod, const_name
      path_suffix = qualified_name.underscore

      file_path = search_for_file(path_suffix)

      if file_path
        expanded = File.expand_path(file_path)
        expanded.sub!(/\.rb\z/, '')

        if loading.include?(expanded)
          raise "Circular dependency detected while autoloading constant #{qualified_name}"
        else
          require_or_load(expanded, qualified_name)
          raise LoadError, "Unable to autoload constant #{qualified_name}, expected #{file_path} to define it" unless from_mod.const_defined?(const_name, false)
          #nodyna <const_get-1119> <CG MODERATE (change-prone variable)>
          return from_mod.const_get(const_name)
        end
      elsif mod = autoload_module!(from_mod, const_name, qualified_name, path_suffix)
        return mod
      elsif (parent = from_mod.parent) && parent != from_mod &&
            ! from_mod.parents.any? { |p| p.const_defined?(const_name, false) }
        begin
          return parent.const_missing(const_name)
        rescue NameError => e
          raise unless e.missing_name? qualified_name_for(parent, const_name)
        end
      end

      name_error = NameError.new("uninitialized constant #{qualified_name}", const_name)
      name_error.set_backtrace(caller.reject {|l| l.starts_with? __FILE__ })
      raise name_error
    end

    def remove_unloadable_constants!
      autoloaded_constants.each { |const| remove_constant const }
      autoloaded_constants.clear
      Reference.clear!
      explicitly_unloadable_constants.each { |const| remove_constant const }
    end

    class ClassCache
      def initialize
        @store = ThreadSafe::Cache.new
      end

      def empty?
        @store.empty?
      end

      def key?(key)
        @store.key?(key)
      end

      def get(key)
        key = key.name if key.respond_to?(:name)
        @store[key] ||= Inflector.constantize(key)
      end
      alias :[] :get

      def safe_get(key)
        key = key.name if key.respond_to?(:name)
        @store[key] ||= Inflector.safe_constantize(key)
      end

      def store(klass)
        return self unless klass.respond_to?(:name)
        raise(ArgumentError, 'anonymous classes cannot be cached') if klass.name.empty?
        @store[klass.name] = klass
        self
      end

      def clear!
        @store.clear
      end
    end

    Reference = ClassCache.new

    def reference(klass)
      Reference.store klass
    end

    def constantize(name)
      Reference.get(name)
    end

    def safe_constantize(name)
      Reference.safe_get(name)
    end

    def autoloaded?(desc)
      return false if desc.is_a?(Module) && desc.anonymous?
      name = to_constant_name desc
      return false unless qualified_const_defined? name
      return autoloaded_constants.include?(name)
    end

    def will_unload?(const_desc)
      autoloaded?(const_desc) ||
        explicitly_unloadable_constants.include?(to_constant_name(const_desc))
    end

    def mark_for_unload(const_desc)
      name = to_constant_name const_desc
      if explicitly_unloadable_constants.include? name
        false
      else
        explicitly_unloadable_constants << name
        true
      end
    end

    def new_constants_in(*descs)
      log_call(*descs)

      constant_watch_stack.watch_namespaces(descs)
      aborting = true

      begin
        yield # Now yield to the code that is to define new constants.
        aborting = false
      ensure
        new_constants = constant_watch_stack.new_constants

        log "New constants: #{new_constants * ', '}"
        return new_constants unless aborting

        log "Error during loading, removing partially loaded constants "
        new_constants.each { |c| remove_constant(c) }.clear
      end

      []
    end

    def to_constant_name(desc) #:nodoc:
      case desc
        when String then desc.sub(/^::/, '')
        when Symbol then desc.to_s
        when Module
          desc.name ||
            raise(ArgumentError, "Anonymous modules have no name to be referenced by")
        else raise TypeError, "Not a valid constant descriptor: #{desc.inspect}"
      end
    end

    def remove_constant(const) #:nodoc:
      normalized = const.to_s.sub(/\A::/, '')
      normalized.sub!(/\A(Object::)+/, '')

      constants = normalized.split('::')
      to_remove = constants.pop

      file_path = search_for_file(const.underscore)
      if file_path
        expanded = File.expand_path(file_path)
        expanded.sub!(/\.rb\z/, '')
        self.loaded.delete(expanded)
      end

      if constants.empty?
        parent = Object
      else
        parent_name = constants.join('::')
        return unless qualified_const_defined?(parent_name)
        parent = constantize(parent_name)
      end

      log "removing constant #{const}"

      unless parent.autoload?(to_remove)
        begin
          #nodyna <const_get-1120> <CG COMPLEX (change-prone variable)>
          constantized = parent.const_get(to_remove, false)
        rescue NameError
          log "the constant #{const} is not reachable anymore, skipping"
          return
        else
          constantized.before_remove_const if constantized.respond_to?(:before_remove_const)
        end
      end

      begin
        #nodyna <instance_eval-1121> <IEV COMPLEX (private access)>
        parent.instance_eval { remove_const to_remove }
      rescue NameError
        log "the constant #{const} is not reachable anymore, skipping"
      end
    end

    protected
      def log_call(*args)
        if log_activity?
          arg_str = args.collect { |arg| arg.inspect } * ', '
          /in `([a-z_\?\!]+)'/ =~ caller(1).first
          selector = $1 || '<unknown>'
          log "called #{selector}(#{arg_str})"
        end
      end

      def log(msg)
        logger.debug "Dependencies: #{msg}" if log_activity?
      end

      def log_activity?
        logger && log_activity
      end
  end
end

ActiveSupport::Dependencies.hook!
