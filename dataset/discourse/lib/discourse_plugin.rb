
class DiscoursePlugin

  attr_reader :registry

  def initialize(registry)
    @registry = registry
  end

  def setup
  end

  def self.include_mixins
    mixins.each do |mixin|
      original_class = mixin.to_s.demodulize.sub("Mixin", "")
      dependency_file_name = original_class.underscore
      require_dependency(dependency_file_name)
      #nodyna <send-352> <SD TRIVIAL (public methods)>
      original_class.constantize.send(:include, mixin)
    end
  end

  def self.mixins
    #nodyna <const_get-353> <CG COMPLEX (array)>
    constants.map { |const_name| const_get(const_name) }
             .select { |const| const.class == Module && const.name["Mixin"] }
  end

  def register_js(file, opts={})
    @registry.register_js(file, opts)
  end

  def register_css(file)
    @registry.register_css(file)
  end

  def register_archetype(name, options={})
    @registry.register_archetype(name, options)
  end

  def listen_for(event_name)
    return unless self.respond_to?(event_name)
    DiscourseEvent.on(event_name, &self.method(event_name))
  end

end

