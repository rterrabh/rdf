require "blacklist"
require "caveats"
require "cmd/options"
require "formula"
require "keg"
require "tab"
require "utils/json"

module Homebrew
  def info
    if ARGV.json == "v1"
      print_json
    elsif ARGV.flag? "--github"
      exec_browser(*ARGV.formulae.map { |f| github_info(f) })
    else
      print_info
    end
  end

  def print_info
    if ARGV.named.empty?
      if HOMEBREW_CELLAR.exist?
        count = Formula.racks.length
        puts "#{count} keg#{plural(count)}, #{HOMEBREW_CELLAR.abv}"
      end
    else
      ARGV.named.each_with_index do |f, i|
        puts unless i == 0
        begin
          if f.include?("/") || File.exist?(f)
            info_formula Formulary.factory(f)
          else
            info_formula Formulary.find_with_priority(f)
          end
        rescue FormulaUnavailableError
          if (blacklist = blacklisted?(f))
            puts blacklist
          else
            raise
          end
        end
      end
    end
  end

  def print_json
    ff = if ARGV.include? "--all"
      Formula
    elsif ARGV.include? "--installed"
      Formula.installed
    else
      ARGV.formulae
    end
    json = ff.map(&:to_hash)
    puts Utils::JSON.dump(json)
  end

  def github_fork
    if (HOMEBREW_REPOSITORY/".git").directory?
      if `git remote -v` =~ %r{origin\s+(https?://|git(?:@|://))github.com[:/](.+)/homebrew}
        $2
      end
    end
  end

  def github_info(f)
    if f.tap?
      user, repo = f.tap.split("/", 2)
      path = f.path.relative_path_from(HOMEBREW_LIBRARY.join("Taps", f.tap))
      "https://github.com/#{user}/#{repo}/blob/master/#{path}"
    elsif f.core_formula?
      user = f.path.parent.cd { github_fork }
      path = f.path.relative_path_from(HOMEBREW_REPOSITORY)
      "https://github.com/#{user}/homebrew/blob/master/#{path}"
    else
      f.path
    end
  end

  def info_formula(f)
    specs = []

    if stable = f.stable
      s = "stable #{stable.version}"
      s += " (bottled)" if stable.bottled?
      specs << s
    end

    if devel = f.devel
      s = "devel #{devel.version}"
      s += " (bottled)" if devel.bottled?
      specs << s
    end

    specs << "HEAD" if f.head

    puts "#{f.full_name}: #{specs*", "}#{" (pinned)" if f.pinned?}"

    puts f.desc if f.desc

    puts f.homepage

    if f.keg_only?
      puts
      puts "This formula is keg-only."
      puts f.keg_only_reason
      puts
    end

    conflicts = f.conflicts.map(&:name).sort!
    puts "Conflicts with: #{conflicts*", "}" unless conflicts.empty?

    if f.rack.directory?
      kegs = f.rack.subdirs.map { |keg| Keg.new(keg) }.sort_by(&:version)
      kegs.each do |keg|
        puts "#{keg} (#{keg.abv})#{" *" if keg.linked?}"
        tab = Tab.for_keg(keg).to_s
        puts "  #{tab}" unless tab.empty?
      end
    else
      puts "Not installed"
    end

    history = github_info(f)
    puts "From: #{history}" if history

    unless f.deps.empty?
      ohai "Dependencies"
      %w[build required recommended optional].map do |type|
        #nodyna <send-611> <SD MODERATE (array)>
        deps = f.deps.send(type).uniq
        puts "#{type.capitalize}: #{decorate_dependencies deps}" unless deps.empty?
      end
    end

    unless f.options.empty?
      ohai "Options"
      Homebrew.dump_options_for_formula f
    end

    c = Caveats.new(f)
    ohai "Caveats", c.caveats unless c.empty?
  end

  def decorate_dependencies(dependencies)
    tick = ["2714".hex].pack("U*")
    cross = ["2718".hex].pack("U*")

    deps_status = dependencies.collect do |dep|
      if dep.installed?
        color = Tty.green
        symbol = tick
      else
        color = Tty.red
        symbol = cross
      end
      if ENV["HOMEBREW_NO_EMOJI"]
        colored_dep = "#{color}#{dep}"
      else
        colored_dep = "#{dep} #{color}#{symbol}"
      end
      "#{colored_dep}#{Tty.reset}"
    end
    deps_status * ", "
  end
end
