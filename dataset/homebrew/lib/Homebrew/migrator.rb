require "formula"
require "formula_lock"
require "keg"
require "tab"
require "tap_migrations"

class Migrator
  class MigrationNeededError < RuntimeError
    def initialize(formula)
      super <<-EOS.undent
        Please run `brew migrate #{formula.oldname}`
      EOS
    end
  end

  class MigratorNoOldnameError < RuntimeError
    def initialize(formula)
      super "#{formula.name} doesn't replace any formula."
    end
  end

  class MigratorNoOldpathError < RuntimeError
    def initialize(formula)
      super "#{HOMEBREW_CELLAR/formula.oldname} doesn't exist."
    end
  end

  class MigratorDifferentTapsError < RuntimeError
    def initialize(formula, tap)
      msg = if tap == "Homebrew/homebrew"
        "Please try to use #{formula.oldname} to refer the formula.\n"
      elsif tap
        user, repo = tap.split("/")
        repo.sub!("homebrew-", "")
        "Please try to use fully-qualified #{user}/#{repo}/#{formula.oldname} to refer the formula.\n"
      end

      super <<-EOS.undent

      EOS
    end
  end

  attr_reader :formula

  attr_reader :oldname

  attr_reader :old_cellar

  attr_reader :old_pin_record

  attr_reader :old_opt_record

  attr_reader :old_linked_keg

  attr_reader :old_linked_keg_record

  attr_reader :old_tabs

  attr_reader :old_tap

  attr_reader :old_pin_link_record

  attr_reader :newname

  attr_reader :new_cellar

  attr_reader :new_pin_record

  attr_reader :new_linked_keg_record

  def initialize(formula)
    @oldname = formula.oldname
    @newname = formula.name
    raise MigratorNoOldnameError.new(formula) unless oldname

    @formula = formula
    @old_cellar = HOMEBREW_CELLAR/formula.oldname
    raise MigratorNoOldpathError.new(formula) unless old_cellar.exist?

    @old_tabs = old_cellar.subdirs.map { |d| Tab.for_keg(Keg.new(d)) }
    @old_tap = old_tabs.first.tap

    if !ARGV.force? && !from_same_taps?
      raise MigratorDifferentTapsError.new(formula, old_tap)
    end

    @new_cellar = HOMEBREW_CELLAR/formula.name

    if @old_linked_keg = get_linked_old_linked_keg
      @old_linked_keg_record = old_linked_keg.linked_keg_record if old_linked_keg.linked?
      @old_opt_record = old_linked_keg.opt_record if old_linked_keg.optlinked?
      @new_linked_keg_record = HOMEBREW_CELLAR/"#{newname}/#{File.basename(old_linked_keg)}"
    end

    @old_pin_record = HOMEBREW_LIBRARY/"PinnedKegs"/oldname
    @new_pin_record = HOMEBREW_LIBRARY/"PinnedKegs"/newname
    @pinned = old_pin_record.symlink?
    @old_pin_link_record = old_pin_record.readlink if @pinned
  end

  def fix_tabs
    old_tabs.each do |tab|
      tab.source["tap"] = formula.tap
      tab.write
    end
  end

  def from_same_taps?
    if formula.tap == old_tap
      true
    elsif TAP_MIGRATIONS && (rec = TAP_MIGRATIONS[formula.oldname]) \
        && rec == formula.tap.sub("homebrew-", "") && old_tap == "Homebrew/homebrew"
      fix_tabs
      true
    elsif formula.tap
      false
    end
  end

  def get_linked_old_linked_keg
    kegs = old_cellar.subdirs.map { |d| Keg.new(d) }
    kegs.detect(&:linked?) || kegs.detect(&:optlinked?)
  end

  def pinned?
    @pinned
  end

  def migrate
    if new_cellar.exist?
      onoe "#{new_cellar} already exists; remove it manually and run brew migrate #{oldname}."
      return
    end

    begin
      oh1 "Migrating #{Tty.green}#{oldname}#{Tty.white} to #{Tty.green}#{newname}#{Tty.reset}"
      lock
      unlink_oldname
      move_to_new_directory
      repin
      link_newname unless old_linked_keg.nil?
      link_oldname_opt
      link_oldname_cellar
      update_tabs
    rescue Interrupt
      ignore_interrupts { backup_oldname }
    rescue Exception => e
      onoe "Error occured while migrating."
      puts e
      puts e.backtrace if ARGV.debug?
      puts "Backuping..."
      ignore_interrupts { backup_oldname }
    ensure
      unlock
    end
  end

  def move_to_new_directory
    puts "Moving to: #{new_cellar}"
    FileUtils.mv(old_cellar, new_cellar)
  end

  def repin
    if pinned?
      src_oldname = old_pin_record.dirname.join(old_pin_link_record).expand_path
      new_pin_record.make_relative_symlink(src_oldname.sub(oldname, newname))
      old_pin_record.delete
    end
  end

  def unlink_oldname
    oh1 "Unlinking #{Tty.green}#{oldname}#{Tty.reset}"
    old_cellar.subdirs.each do |d|
      keg = Keg.new(d)
      keg.unlink
    end
  end

  def link_newname
    oh1 "Linking #{Tty.green}#{newname}#{Tty.reset}"
    new_keg = Keg.new(new_linked_keg_record)

    if formula.keg_only? || !old_linked_keg_record
      begin
        new_keg.optlink
      rescue Keg::LinkError => e
        onoe "Failed to create #{formula.opt_prefix}"
        raise
      end
      return
    end

    new_keg.remove_linked_keg_record if new_keg.linked?

    begin
      new_keg.link
    rescue Keg::ConflictError => e
      onoe "Error while executing `brew link` step on #{newname}"
      puts e
      puts
      puts "Possible conflicting files are:"
      mode = OpenStruct.new(:dry_run => true, :overwrite => true)
      new_keg.link(mode)
      raise
    rescue Keg::LinkError => e
      onoe "Error while linking"
      puts e
      puts
      puts "You can try again using:"
      puts "  brew link #{formula.name}"
    rescue Exception => e
      onoe "An unexpected error occurred during linking"
      puts e
      puts e.backtrace if ARGV.debug?
      ignore_interrupts { new_keg.unlink }
      raise
    end
  end

  def link_oldname_opt
    if old_opt_record
      old_opt_record.delete if old_opt_record.symlink?
      old_opt_record.make_relative_symlink(new_linked_keg_record)
    end
  end

  def update_tabs
    new_tabs = new_cellar.subdirs.map { |d| Tab.for_keg(Keg.new(d)) }
    new_tabs.each do |tab|
      tab.source["path"] = formula.path.to_s if tab.source["path"]
      tab.write
    end
  end

  def unlink_oldname_opt
    return unless old_opt_record
    if old_opt_record.symlink? && old_opt_record.exist? \
        && new_linked_keg_record.exist? \
        && new_linked_keg_record.realpath == old_opt_record.realpath
      old_opt_record.unlink
      old_opt_record.parent.rmdir_if_possible
    end
  end

  def link_oldname_cellar
    old_cellar.delete if old_cellar.symlink? || old_cellar.exist?
    old_cellar.make_relative_symlink(formula.rack)
  end

  def unlink_oldname_cellar
    if (old_cellar.symlink? && !old_cellar.exist?) || (old_cellar.symlink? \
          && formula.rack.exist? && formula.rack.realpath == old_cellar.realpath)
      old_cellar.unlink
    end
  end

  def backup_oldname
    unlink_oldname_opt
    unlink_oldname_cellar
    backup_oldname_cellar
    backup_old_tabs

    if pinned? && !old_pin_record.symlink?
      src_oldname = old_pin_record.dirname.join(old_pin_link_record).expand_path
      old_pin_record.make_relative_symlink(src_oldname)
      new_pin_record.delete
    end

    if new_cellar.exist?
      new_cellar.subdirs.each do |d|
        newname_keg = Keg.new(d)
        newname_keg.unlink
        newname_keg.uninstall
      end
    end

    unless old_linked_keg.nil?
      if old_linked_keg_record
        begin
          old_linked_keg.link
        rescue Keg::LinkError
          old_linked_keg.unlink
          raise
        rescue Keg::AlreadyLinkedError
          old_linked_keg.unlink
          retry
        end
      else
        old_linked_keg.optlink
      end
    end
  end

  def backup_oldname_cellar
    unless old_cellar.exist?
      FileUtils.mv(new_cellar, old_cellar)
    end
  end

  def backup_old_tabs
    old_tabs.each(&:write)
  end

  def lock
    @newname_lock = FormulaLock.new newname
    @oldname_lock = FormulaLock.new oldname
    @newname_lock.lock
    @oldname_lock.lock
  end

  def unlock
    @newname_lock.unlock
    @oldname_lock.unlock
  end
end
