require 'digest/sha1'
require 'fileutils'
require_dependency 'plugin/metadata'
require_dependency 'plugin/auth_provider'

class Plugin::Instance

  attr_accessor :path, :metadata
  attr_reader :admin_route

  # Memoized array readers
  [:assets, :auth_providers, :color_schemes, :initializers, :javascripts, :styles].each do |att|
    class_eval %Q{
      def #{att}
        @#{att} ||= []
      end
    }
  end

  def seed_data
    @seed_data ||= {}
  end

  def self.find_all(parent_path)
    [].tap { |plugins|
      # also follows symlinks - http://stackoverflow.com/q/357754
      Dir["#{parent_path}/**/*/**/plugin.rb"].sort.each do |path|
        source = File.read(path)
        metadata = Plugin::Metadata.parse(source)
        plugins << self.new(metadata, path)
      end
    }
  end

  def initialize(metadata=nil, path=nil)
    @metadata = metadata
    @path = path
    @idx = 0
  end

  def add_admin_route(label, location)
    @admin_route = {label: label, location: location}
  end

  def enabled?
    #nodyna <ID:send-49> <SD COMPLEX (change-prone variables)>
    @enabled_site_setting ? SiteSetting.send(@enabled_site_setting) : true
  end

  delegate :name, to: :metadata

  def add_to_serializer(serializer, attr, define_include_method=true, &block)
    klass = "#{serializer.to_s.classify}Serializer".constantize

    klass.attributes(attr) unless attr.to_s.start_with?("include_")

    #nodyna <ID:send-50> <SD MODERATE (private methods)>
    #nodyna <ID:define_method-6> <DM MODERATE (events)>
    klass.send(:define_method, attr, &block)

    return unless define_include_method

    # Don't include serialized methods if the plugin is disabled
    plugin = self
    #nodyna <ID:send-51> <SD MODERATE (private methods)>
    #nodyna <ID:define_method-7> <DM MODERATE (events)>
    klass.send(:define_method, "include_#{attr}?") { plugin.enabled? }
  end

  # Extend a class but check that the plugin is enabled
  # for class methods use `add_class_method`
  def add_to_class(klass, attr, &block)
    klass = klass.to_s.classify.constantize

    hidden_method_name = :"#{attr}_without_enable_check"
    #nodyna <ID:send-52> <SD COMPLEX (private methods)>
    #nodyna <ID:define_method-8> <DM COMPLEX (events)>
    klass.send(:define_method, hidden_method_name, &block)

    plugin = self
    #nodyna <ID:send-53> <SD COMPLEX (private methods)>
    #nodyna <ID:define_method-9> <DM COMPLEX (events)>
    klass.send(:define_method, attr) do |*args|
      #nodyna <ID:send-54> <SD COMPLEX (array)>
      send(hidden_method_name, *args) if plugin.enabled?
    end
  end

  # Adds a class method to a class, respecting if plugin is enabled
  def add_class_method(klass, attr, &block)
    klass = klass.to_s.classify.constantize

    hidden_method_name = :"#{attr}_without_enable_check"
    #nodyna <ID:send-55> <SD COMPLEX (private methods)>
    klass.send(:define_singleton_method, hidden_method_name, &block)

    plugin = self
    #nodyna <ID:send-56> <SD COMPLEX (private methods)>
    klass.send(:define_singleton_method, attr) do |*args|
      #nodyna <ID:send-57> <SD COMPLEX (change-prone variables)>
      send(hidden_method_name, *args) if plugin.enabled?
    end
  end

  def add_model_callback(klass, callback, &block)
    klass = klass.to_s.classify.constantize
    plugin = self

    # generate a unique method name
    method_name = "#{plugin.name}_#{klass.name}_#{callback}#{@idx}".underscore
    @idx += 1
    hidden_method_name = :"#{method_name}_without_enable_check"
    #nodyna <ID:send-58> <SD COMPLEX (private methods)>
    #nodyna <ID:define_method-10> <DM COMPLEX (events)>
    klass.send(:define_method, hidden_method_name, &block)

    #nodyna <ID:send-59> <SD COMPLEX (change-prone variables)>
    klass.send(callback) do |*args|
      #nodyna <ID:send-60> <SD COMPLEX (array)>
      send(hidden_method_name, *args) if plugin.enabled?
    end

  end

  # Add validation method but check that the plugin is enabled
  def validate(klass, name, &block)
    klass = klass.to_s.classify.constantize
    #nodyna <ID:send-61> <SD MODERATE (private methods)>
    #nodyna <ID:define_method-11> <DM MODERATE (events)>
    klass.send(:define_method, name, &block)

    plugin = self
    klass.validate(name, if: -> { plugin.enabled? })
  end

  # will make sure all the assets this plugin needs are registered
  def generate_automatic_assets!
    paths = []
    automatic_assets.each do |path, contents|
      unless File.exists? path
        ensure_directory path
        File.open(path,"w") do |f|
          f.write(contents)
        end
      end
      paths << path
    end

    delete_extra_automatic_assets(paths)

    paths
  end

  def delete_extra_automatic_assets(good_paths)
    return unless Dir.exists? auto_generated_path

    filenames = good_paths.map{|f| File.basename(f)}
    # nuke old files
    Dir.foreach(auto_generated_path) do |p|
      next if [".", ".."].include?(p)
      next if filenames.include?(p)
      File.delete(auto_generated_path + "/#{p}")
    end
  end

  def ensure_directory(path)
    dirname = File.dirname(path)
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
  end

  def auto_generated_path
    File.dirname(path) << "/auto_generated"
  end

  def after_initialize(&block)
    initializers << block
  end

  # A proxy to `DiscourseEvent.on` which does nothing if the plugin is disabled
  def on(event_name, &block)
    DiscourseEvent.on(event_name) do |*args|
      block.call(*args) if enabled?
    end
  end

  def notify_after_initialize
    color_schemes.each do |c|
      ColorScheme.create_from_base(name: c[:name], colors: c[:colors]) unless ColorScheme.where(name: c[:name]).exists?
    end

    initializers.each do |callback|
      callback.call(self)
    end
  end

  def listen_for(event_name)
    return unless self.respond_to?(event_name)
    DiscourseEvent.on(event_name, &self.method(event_name))
  end

  def register_css(style)
    styles << style
  end

  def register_javascript(js)
    javascripts << js
  end

  def register_custom_html(hash)
    DiscoursePluginRegistry.custom_html ||= {}
    DiscoursePluginRegistry.custom_html.merge!(hash)
  end

  def register_asset(file, opts=nil)
    full_path = File.dirname(path) << "/assets/" << file
    assets << [full_path, opts]
  end

  def register_color_scheme(name, colors)
    color_schemes << {name: name, colors: colors}
  end

  def register_seed_data(key, value)
    seed_data[key] = value
  end

  def automatic_assets
    css = styles.join("\n")
    js = javascripts.join("\n")

    auth_providers.each do |auth|
      overrides = ""
      overrides = ", titleOverride: '#{auth.title}'" if auth.title
      overrides << ", messageOverride: '#{auth.message}'" if auth.message
      overrides << ", frameWidth: '#{auth.frame_width}'" if auth.frame_width
      overrides << ", frameHeight: '#{auth.frame_height}'" if auth.frame_height

      js << "Discourse.LoginMethod.register(Discourse.LoginMethod.create({name: '#{auth.name}'#{overrides}}));\n"

      if auth.glyph
        css << ".btn-social.#{auth.name}:before{ content: '#{auth.glyph}'; }\n"
      end

      if auth.background_color
        css << ".btn-social.#{auth.name}{ background: #{auth.background_color}; }\n"
      end
    end

    # Generate an IIFE for the JS
    js = "(function(){#{js}})();" if js.present?

    result = []
    result << [css, 'css'] if css.present?
    result << [js, 'js'] if js.present?

    result.map do |asset, extension|
      hash = Digest::SHA1.hexdigest asset
      ["#{auto_generated_path}/plugin_#{hash}.#{extension}", asset]
    end

  end


  # note, we need to be able to parse seperately to activation.
  # this allows us to present information about a plugin in the UI
  # prior to activations
  def activate!

    if @path
      # Automatically include all ES6 JS and hbs files
      root_path = "#{File.dirname(@path)}/assets/javascripts"
      DiscoursePluginRegistry.register_glob(root_path, 'js.es6')
      DiscoursePluginRegistry.register_glob(root_path, 'hbs')

      admin_path = "#{File.dirname(@path)}/admin/assets/javascripts"
      DiscoursePluginRegistry.register_glob(admin_path, 'js.es6', admin: true)
      DiscoursePluginRegistry.register_glob(admin_path, 'hbs', admin: true)
    end

    #nodyna <ID:instance_eval-1> <IEV COMPLEX (block execution)>
    self.instance_eval File.read(path), path
    if auto_assets = generate_automatic_assets!
      assets.concat auto_assets.map{|a| [a]}
    end

    register_assets! unless assets.blank?

    seed_data.each do |key, value|
      DiscoursePluginRegistry.register_seed_data(key, value)
    end

    # TODO: possibly amend this to a rails engine

    # Automatically include assets
    Rails.configuration.assets.paths << auto_generated_path
    Rails.configuration.assets.paths << File.dirname(path) + "/assets"
    Rails.configuration.assets.paths << File.dirname(path) + "/admin/assets"

    # Automatically include rake tasks
    Rake.add_rakelib(File.dirname(path) + "/lib/tasks")

    # Automatically include migrations
    Rails.configuration.paths["db/migrate"] << File.dirname(path) + "/db/migrate"

    public_data = File.dirname(path) + "/public"
    if Dir.exists?(public_data)
      target = Rails.root.to_s + "/public/plugins/"
      `mkdir -p #{target}`
      target << name.gsub(/\s/,"_")
      # TODO a cleaner way of registering and unregistering
      `rm -f #{target}`
      `ln -s #{public_data} #{target}`
    end
  end


  def auth_provider(opts)
    provider = Plugin::AuthProvider.new
    [:glyph, :background_color, :title, :message, :frame_width, :frame_height, :authenticator].each do |sym|
      #nodyna <ID:send-62> <SD MODERATE (array)>
      provider.send "#{sym}=", opts.delete(sym)
    end
    auth_providers << provider
  end


  # shotgun approach to gem loading, in future we need to hack bundler
  #  to at least determine dependencies do not clash before loading
  #
  # Additionally we want to support multiple ruby versions correctly and so on
  #
  # This is a very rough initial implementation
  def gem(name, version, opts = {})
    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"
    spec_path = gems_path + "/specifications"
    spec_file = spec_path + "/#{name}-#{version}.gemspec"
    unless File.exists? spec_file
      command = "gem install #{name} -v #{version} -i #{gems_path} --no-document --ignore-dependencies"
      if opts[:source]
        command << " --source #{opts[:source]}"
      end
      puts command
      puts `#{command}`
    end
    if File.exists? spec_file
      spec = Gem::Specification.load spec_file
      spec.activate
      unless opts[:require] == false
        require opts[:require_name] ? opts[:require_name] : name
      end
    else
      puts "You are specifying the gem #{name} in #{path}, however it does not exist!"
      exit(-1)
    end
  end

  def enabled_site_setting(setting=nil)
    if setting
      @enabled_site_setting = setting
    else
      @enabled_site_setting
    end
  end

  protected

  def register_assets!
    assets.each do |asset, opts|
      DiscoursePluginRegistry.register_asset(asset, opts)
    end
  end

end
