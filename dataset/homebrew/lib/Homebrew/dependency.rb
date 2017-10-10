require "dependable"

class Dependency
  include Dependable

  attr_reader :name, :tags, :env_proc, :option_name

  DEFAULT_ENV_PROC = proc {}

  def initialize(name, tags = [], env_proc = DEFAULT_ENV_PROC, option_name = name)
    @name = name
    @tags = tags
    @env_proc = env_proc
    @option_name = option_name
  end

  def to_s
    name
  end

  def ==(other)
    instance_of?(other.class) && name == other.name && tags == other.tags
  end
  alias_method :eql?, :==

  def hash
    name.hash ^ tags.hash
  end

  def to_formula
    formula = Formulary.factory(name)
    formula.build = BuildOptions.new(options, formula.options)
    formula
  end

  def installed?
    to_formula.installed?
  end

  def satisfied?(inherited_options)
    installed? && missing_options(inherited_options).empty?
  end

  def missing_options(inherited_options)
    required = options | inherited_options
    required - Tab.for_formula(to_formula).used_options
  end

  def modify_build_environment
    env_proc.call unless env_proc.nil?
  end

  def inspect
    "#<#{self.class.name}: #{name.inspect} #{tags.inspect}>"
  end

  def _dump(*)
    Marshal.dump([name, tags])
  end

  def self._load(marshaled)
    new(*Marshal.load(marshaled))
  end

  class << self
    def expand(dependent, deps = dependent.deps, &block)
      expanded_deps = []

      deps.each do |dep|
        next if dependent.name == dep.name

        case action(dependent, dep, &block)
        when :prune
          next
        when :skip
          expanded_deps.concat(expand(dep.to_formula, &block))
        when :keep_but_prune_recursive_deps
          expanded_deps << dep
        else
          expanded_deps.concat(expand(dep.to_formula, &block))
          expanded_deps << dep
        end
      end

      merge_repeats(expanded_deps)
    end

    def action(dependent, dep, &_block)
      catch(:action) do
        if block_given?
          yield dependent, dep
        elsif dep.optional? || dep.recommended?
          prune unless dependent.build.with?(dep)
        end
      end
    end

    def prune
      throw(:action, :prune)
    end

    def skip
      throw(:action, :skip)
    end

    def keep_but_prune_recursive_deps
      throw(:action, :keep_but_prune_recursive_deps)
    end

    def merge_repeats(all)
      grouped = all.group_by(&:name)

      all.map(&:name).uniq.map do |name|
        deps = grouped.fetch(name)
        dep  = deps.first
        tags = deps.flat_map(&:tags).uniq
        dep.class.new(name, tags, dep.env_proc)
      end
    end
  end
end

class TapDependency < Dependency
  attr_reader :tap

  def initialize(name, tags = [], env_proc = DEFAULT_ENV_PROC, option_name = name.split("/").last)
    @tap = name.rpartition("/").first
    super(name, tags, env_proc, option_name)
  end

  def installed?
    super
  rescue FormulaUnavailableError
    false
  end
end
