require "dependable"
require "dependency"
require "dependencies"
require "build_environment"

class Requirement
  include Dependable

  attr_reader :tags, :name, :cask, :download, :default_formula
  alias_method :option_name, :name

  def initialize(tags = [])
    @default_formula = self.class.default_formula
    @cask ||= self.class.cask
    @download ||= self.class.download
    tags.each do |tag|
      next unless tag.is_a? Hash
      @cask ||= tag[:cask]
      @download ||= tag[:download]
    end
    @tags = tags
    @tags << :build if self.class.build
    @name ||= infer_name
  end

  def message
    s = ""
    if cask
      s +=  <<-EOS.undent

        You can install with Homebrew Cask:
          brew install Caskroom/cask/#{cask}
      EOS
    end

    if download
      s += <<-EOS.undent

        You can download from:
      EOS
    end
    s
  end

  def satisfied?
    #nodyna <instance_eval-667> <IEV COMPLEX (block execution)>
    result = self.class.satisfy.yielder { |p| instance_eval(&p) }
    @satisfied_result = result
    !!result
  end

  def fatal?
    self.class.fatal || false
  end

  def default_formula?
    self.class.default_formula || false
  end

  def modify_build_environment
    #nodyna <instance_eval-668> <IEV COMPLEX (block execution)>
    instance_eval(&env_proc) if env_proc

    if Pathname === @satisfied_result
      parent = @satisfied_result.parent
      unless ENV["PATH"].split(File::PATH_SEPARATOR).include?(parent.to_s)
        ENV.append_path("PATH", parent)
      end
    end
  end

  def env
    self.class.env
  end

  def env_proc
    self.class.env_proc
  end

  def ==(other)
    instance_of?(other.class) && name == other.name && tags == other.tags
  end
  alias_method :eql?, :==

  def hash
    name.hash ^ tags.hash
  end

  def inspect
    "#<#{self.class.name}: #{name.inspect} #{tags.inspect}>"
  end

  def to_dependency
    f = self.class.default_formula
    raise "No default formula defined for #{inspect}" if f.nil?
    if HOMEBREW_TAP_FORMULA_REGEX === f
      TapDependency.new(f, tags, method(:modify_build_environment), name)
    else
      Dependency.new(f, tags, method(:modify_build_environment), name)
    end
  end

  private

  def infer_name
    klass = self.class.name || self.class.to_s
    klass.sub!(/(Dependency|Requirement)$/, "")
    klass.sub!(/^(\w+::)*/, "")
    klass.downcase
  end

  def which(cmd)
    super(cmd, ORIGINAL_PATHS.join(File::PATH_SEPARATOR))
  end

  class << self
    include BuildEnvironmentDSL

    attr_reader :env_proc
    attr_rw :fatal, :default_formula
    attr_rw :cask, :download
    attr_rw :build

    def satisfy(options = {}, &block)
      @satisfied ||= Requirement::Satisfier.new(options, &block)
    end

    def env(*settings, &block)
      if block_given?
        @env_proc = block
      else
        super
      end
    end
  end

  class Satisfier
    def initialize(options, &block)
      case options
      when Hash
        @options = { :build_env => true }
        @options.merge!(options)
      else
        @satisfied = options
      end
      @proc = block
    end

    def yielder
      if instance_variable_defined?(:@satisfied)
        @satisfied
      elsif @options[:build_env]
        require "extend/ENV"
        ENV.with_build_environment { yield @proc }
      else
        yield @proc
      end
    end
  end

  class << self
    def expand(dependent, &block)
      reqs = Requirements.new

      formulae = dependent.recursive_dependencies.map(&:to_formula)
      formulae.unshift(dependent)

      formulae.each do |f|
        f.requirements.each do |req|
          if prune?(f, req, &block)
            next
          else
            reqs << req
          end
        end
      end

      reqs
    end

    def prune?(dependent, req, &_block)
      catch(:prune) do
        if block_given?
          yield dependent, req
        elsif req.optional? || req.recommended?
          prune unless dependent.build.with?(req)
        end
      end
    end

    def prune
      throw(:prune, true)
    end
  end
end
