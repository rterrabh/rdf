require 'rubygems/dependency'
require 'rubygems/exceptions'
require 'rubygems/util/list'

require 'uri'
require 'net/http'


class Gem::Resolver


  DEBUG_RESOLVER = !ENV['DEBUG_RESOLVER'].nil?

  require 'pp' if DEBUG_RESOLVER


  attr_reader :conflicts


  attr_accessor :development


  attr_accessor :development_shallow


  attr_accessor :ignore_dependencies


  attr_reader :missing

  attr_reader :stats


  attr_accessor :skip_gems


  attr_accessor :soft_missing


  def self.compose_sets *sets
    sets.compact!

    sets = sets.map do |set|
      case set
      when Gem::Resolver::BestSet then
        set
      when Gem::Resolver::ComposedSet then
        set.sets
      else
        set
      end
    end.flatten

    case sets.length
    when 0 then
      raise ArgumentError, 'one set in the composition must be non-nil'
    when 1 then
      sets.first
    else
      Gem::Resolver::ComposedSet.new(*sets)
    end
  end


  def self.for_current_gems needed
    new needed, Gem::Resolver::CurrentSet.new
  end


  def initialize needed, set = nil
    @set = set || Gem::Resolver::IndexSet.new
    @needed = needed

    @conflicts           = []
    @development         = false
    @development_shallow = false
    @ignore_dependencies = false
    @missing             = []
    @skip_gems           = {}
    @soft_missing        = false
    @stats               = Gem::Resolver::Stats.new
  end

  def explain stage, *data # :nodoc:
    return unless DEBUG_RESOLVER

    d = data.map { |x| x.pretty_inspect }.join(", ")
    $stderr.printf "%10s %s\n", stage.to_s.upcase, d
  end

  def explain_list stage # :nodoc:
    return unless DEBUG_RESOLVER

    data = yield
    $stderr.printf "%10s (%d entries)\n", stage.to_s.upcase, data.size
    PP.pp data, $stderr unless data.empty?
  end


  def activation_request dep, possible # :nodoc:
    spec = possible.pop

    explain :activate, [spec.full_name, possible.size]
    explain :possible, possible

    activation_request =
      Gem::Resolver::ActivationRequest.new spec, dep, possible

    return spec, activation_request
  end

  def requests s, act, reqs=nil # :nodoc:
    return reqs if @ignore_dependencies

    s.fetch_development_dependencies if @development

    s.dependencies.reverse_each do |d|
      next if d.type == :development and not @development
      next if d.type == :development and @development_shallow and
              act.development?
      next if d.type == :development and @development_shallow and
              act.parent

      reqs.add Gem::Resolver::DependencyRequest.new(d, act)
      @stats.requirement!
    end

    @set.prefetch reqs

    @stats.record_requirements reqs

    reqs
  end


  def resolve
    @conflicts = []

    needed = Gem::Resolver::RequirementList.new

    @needed.reverse_each do |n|
      request = Gem::Resolver::DependencyRequest.new n, nil

      needed.add request
      @stats.requirement!
    end

    @stats.record_requirements needed

    res = resolve_for needed, nil

    raise Gem::DependencyResolutionError, res if
      res.kind_of? Gem::Resolver::Conflict

    res.to_a
  end


  def find_possible dependency # :nodoc:
    all = @set.find_all dependency

    if (skip_dep_gems = skip_gems[dependency.name]) && !skip_dep_gems.empty?
      matching = all.select do |api_spec|
        skip_dep_gems.any? { |s| api_spec.version == s.version }
      end

      all = matching unless matching.empty?
    end

    matching_platform = select_local_platforms all

    return matching_platform, all
  end

  def handle_conflict(dep, existing) # :nodoc:


    if existing.others_possible?
      conflict =
        Gem::Resolver::Conflict.new dep, existing
    elsif dep.requester
      depreq = dep.requester.request
      conflict =
        Gem::Resolver::Conflict.new depreq, existing, dep
    elsif existing.request.requester.nil?
      conflict =
        Gem::Resolver::Conflict.new dep, existing
    else
      raise Gem::DependencyError, "Unable to figure out how to unwind conflict"
    end

    @conflicts << conflict unless @conflicts.include? conflict

    return conflict
  end

  State = Struct.new(:needed, :specs, :dep, :spec, :possibles, :conflicts) do
    def summary # :nodoc:
      nd = needed.map { |s| s.to_s }.sort if nd

      if specs then
        ss = specs.map { |s| s.full_name }.sort
        ss.unshift ss.length
      end

      d = dep.to_s
      d << " from #{dep.requester.full_name}" if dep.requester

      ps = possibles.map { |p| p.full_name }.sort
      ps.unshift ps.length

      cs = conflicts.map do |(s, c)|
        [s.full_name, c.conflicting_dependencies.map { |cd| cd.to_s }]
      end

      { :needed => nd, :specs => ss, :dep => d, :spec => spec.full_name,
        :possibles => ps, :conflicts => cs }
    end
  end


  def resolve_for needed, specs # :nodoc:
    states = []

    while !needed.empty?
      @stats.iteration!

      dep = needed.remove
      explain :try, [dep, dep.requester ? dep.requester.request : :toplevel]
      explain_list(:next5) { needed.next5 }
      explain_list(:specs) { Array(specs).map { |x| x.full_name }.sort }

      if specs && existing = specs.find { |s| dep.name == s.name }
        next if dep.matches_spec? existing

        conflict = handle_conflict dep, existing

        return conflict unless dep.requester

        explain :conflict, dep, :existing, existing.full_name

        depreq = dep.requester.request

        state = nil
        until states.empty?
          x = states.pop

          i = existing.request.requester
          explain :consider, x.spec.full_name, [depreq.name, dep.name, i ? i.name : :top]

          if x.spec.name == depreq.name or
              x.spec.name == dep.name or
              (i && (i.name == x.spec.name))
            explain :found, x.spec.full_name
            state = x
            break
          end
        end

        return conflict unless state

        @stats.backtracking!

        needed, specs = resolve_for_conflict needed, specs, state

        states << state unless state.possibles.empty?

        next
      end

      matching, all = find_possible dep

      case matching.size
      when 0
        resolve_for_zero dep, all
      when 1
        needed, specs =
          resolve_for_single needed, specs, dep, matching
      else
        needed, specs =
          resolve_for_multiple needed, specs, states, dep, matching
      end
    end

    specs
  end


  def resolve_for_conflict needed, specs, state # :nodoc:
    raise Gem::ImpossibleDependenciesError.new state.dep, state.conflicts if
      state.possibles.empty?

    spec, act = activation_request state.dep, state.possibles

    needed = requests spec, act, state.needed.dup
    specs = Gem::List.prepend state.specs, act

    return needed, specs
  end


  def resolve_for_multiple needed, specs, states, dep, possible # :nodoc:
    possible = possible.sort_by do |s|
      [s.source, s.version, s.platform == Gem::Platform::RUBY ? -1 : 1]
    end

    spec, act = activation_request dep, possible

    states << State.new(needed.dup, specs, dep, spec, possible, [])

    @stats.record_depth states

    explain :states, states.map { |s| s.dep }

    needed = requests spec, act, needed
    specs = Gem::List.prepend specs, act

    return needed, specs
  end


  def resolve_for_single needed, specs, dep, possible # :nodoc:
    spec, act = activation_request dep, possible

    specs = Gem::List.prepend specs, act

    needed = requests spec, act, needed

    return needed, specs
  end


  def resolve_for_zero dep, platform_mismatch # :nodoc:
    @missing << dep

    unless @soft_missing
      exc = Gem::UnsatisfiableDependencyError.new dep, platform_mismatch
      exc.errors = @set.errors

      raise exc
    end
  end


  def select_local_platforms specs # :nodoc:
    specs.select do |spec|
      Gem::Platform.installable? spec
    end
  end

end


Gem::DependencyResolver = Gem::Resolver # :nodoc:

require 'rubygems/resolver/activation_request'
require 'rubygems/resolver/conflict'
require 'rubygems/resolver/dependency_request'
require 'rubygems/resolver/requirement_list'
require 'rubygems/resolver/stats'

require 'rubygems/resolver/set'
require 'rubygems/resolver/api_set'
require 'rubygems/resolver/composed_set'
require 'rubygems/resolver/best_set'
require 'rubygems/resolver/current_set'
require 'rubygems/resolver/git_set'
require 'rubygems/resolver/index_set'
require 'rubygems/resolver/installer_set'
require 'rubygems/resolver/lock_set'
require 'rubygems/resolver/vendor_set'

require 'rubygems/resolver/specification'
require 'rubygems/resolver/spec_specification'
require 'rubygems/resolver/api_specification'
require 'rubygems/resolver/git_specification'
require 'rubygems/resolver/index_specification'
require 'rubygems/resolver/installed_specification'
require 'rubygems/resolver/local_specification'
require 'rubygems/resolver/lock_specification'
require 'rubygems/resolver/vendor_specification'

