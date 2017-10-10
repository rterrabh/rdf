require "cmd/install"
require "cmd/outdated"

module Homebrew
  def upgrade
    FormulaInstaller.prevent_build_flags unless MacOS.has_apple_developer_tools?

    Homebrew.perform_preinstall_checks

    if ARGV.named.empty?
      outdated = Homebrew.outdated_brews(Formula.installed)
      exit 0 if outdated.empty?
    elsif ARGV.named.any?
      outdated = Homebrew.outdated_brews(ARGV.resolved_formulae)

      (ARGV.resolved_formulae - outdated).each do |f|
        if f.rack.directory?
          version = f.rack.subdirs.map { |d| Keg.new(d).version }.max
          onoe "#{f.full_name} #{version} already installed"
        else
          onoe "#{f.full_name} not installed"
        end
      end
      exit 1 if outdated.empty?
    end

    unless upgrade_pinned?
      pinned = outdated.select(&:pinned?)
      outdated -= pinned
    end

    unless outdated.empty?
      oh1 "Upgrading #{outdated.length} outdated package#{plural(outdated.length)}, with result:"
      puts outdated.map { |f| "#{f.full_name} #{f.pkg_version}" } * ", "
    else
      oh1 "No packages to upgrade"
    end

    unless upgrade_pinned? || pinned.empty?
      oh1 "Not upgrading #{pinned.length} pinned package#{plural(pinned.length)}:"
      puts pinned.map { |f| "#{f.full_name} #{f.pkg_version}" } * ", "
    end

    outdated.each { |f| upgrade_formula(f) }
  end

  def upgrade_pinned?
    !ARGV.named.empty?
  end

  def upgrade_formula(f)
    outdated_keg = Keg.new(f.linked_keg.resolved_path) if f.linked_keg.directory?
    tab = Tab.for_formula(f)

    fi = FormulaInstaller.new(f)
    fi.options             = tab.used_options
    fi.build_bottle        = ARGV.build_bottle? || (!f.bottled? && tab.build_bottle?)
    fi.build_from_source   = ARGV.build_from_source?
    fi.verbose             = ARGV.verbose?
    fi.quieter             = ARGV.quieter?
    fi.debug               = ARGV.debug?
    fi.prelude

    oh1 "Upgrading #{f.full_name}"

    outdated_keg.unlink if outdated_keg

    fi.install
    fi.finish

    if f.pinned?
      f.unpin
      f.pin
    end
  rescue FormulaInstallationAlreadyAttemptedError
  rescue CannotInstallFormulaError => e
    ofail e
  rescue BuildError => e
    e.dump
    puts
    Homebrew.failed = true
  rescue DownloadError => e
    ofail e
  ensure
    outdated_keg.link if outdated_keg && !f.installed? rescue nil
  end
end
