
class Gem::StubSpecification < Gem::BasicSpecification
  PREFIX = "# stub: "

  OPEN_MODE = # :nodoc:
    if Object.const_defined? :Encoding then
      'r:UTF-8:-'
    else
      'r'
    end

  class StubLine # :nodoc: all
    attr_reader :parts

    def initialize(data)
      @parts = data[PREFIX.length..-1].split(" ")
    end

    def name
      @parts[0]
    end

    def version
      Gem::Version.new @parts[1]
    end

    def platform
      Gem::Platform.new @parts[2]
    end

    def require_paths
      @parts[3..-1].join(" ").split("\0")
    end
  end

  def initialize(filename)
    self.loaded_from = filename
    @data            = nil
    @extensions      = nil
    @name            = nil
    @spec            = nil
  end


  def activated?
    @activated ||=
    begin
      loaded = Gem.loaded_specs[name]
      loaded && loaded.version == version
    end
  end

  def build_extensions # :nodoc:
    return if default_gem?
    return if extensions.empty?

    to_spec.build_extensions
  end


  def data
    unless @data
      @extensions = []

      open loaded_from, OPEN_MODE do |file|
        begin
          file.readline # discard encoding line
          stubline = file.readline.chomp
          if stubline.start_with?(PREFIX) then
            @data = StubLine.new stubline

            @extensions = $'.split "\0" if
              /\A#{PREFIX}/ =~ file.readline.chomp
          end
        rescue EOFError
        end
      end
    end

    @data ||= to_spec
  end

  private :data


  def extensions
    return @extensions if @extensions

    data # load

    @extensions
  end


  def find_full_gem_path # :nodoc:
    path = File.expand_path File.join gems_dir, full_name
    path.untaint
    path
  end


  def full_require_paths
    @require_paths ||= data.require_paths

    super
  end

  def missing_extensions?
    return false if default_gem?
    return false if extensions.empty?

    to_spec.missing_extensions?
  end


  def name
    @name ||= data.name
  end


  def platform
    @platform ||= data.platform
  end


  def require_paths
    @require_paths ||= data.require_paths

    super
  end


  def to_spec
    @spec ||= if @data then
                Gem.loaded_specs.values.find { |spec|
                  spec.name == name and spec.version == version
                }
              end

    @spec ||= Gem::Specification.load(loaded_from)
    @spec.ignored = @ignored if instance_variable_defined? :@ignored

    @spec
  end


  def valid?
    data
  end


  def version
    @version ||= data.version
  end


  def stubbed?
    data.is_a? StubLine
  end

end

