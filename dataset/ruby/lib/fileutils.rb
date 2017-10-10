
module FileUtils

  def self.private_module_function(name)   #:nodoc:
    module_function name
    private_class_method name
  end

  OPT_TABLE = {}   #:nodoc: internal use only

  def pwd
    Dir.pwd
  end
  module_function :pwd

  alias getwd pwd
  module_function :getwd

  def cd(dir, options = {}, &block) # :yield: dir
    fu_check_options options, OPT_TABLE['cd']
    fu_output_message "cd #{dir}" if options[:verbose]
    Dir.chdir(dir, &block)
    fu_output_message 'cd -' if options[:verbose] and block
  end
  module_function :cd

  alias chdir cd
  module_function :chdir

  OPT_TABLE['cd']    =
  OPT_TABLE['chdir'] = [:verbose]

  def uptodate?(new, old_list)
    return false unless File.exist?(new)
    new_time = File.mtime(new)
    old_list.each do |old|
      if File.exist?(old)
        return false unless new_time > File.mtime(old)
      end
    end
    true
  end
  module_function :uptodate?

  def remove_tailing_slash(dir)
    dir == '/' ? dir : dir.chomp(?/)
  end
  private_module_function :remove_tailing_slash

  def mkdir(list, options = {})
    fu_check_options options, OPT_TABLE['mkdir']
    list = fu_list(list)
    fu_output_message "mkdir #{options[:mode] ? ('-m %03o ' % options[:mode]) : ''}#{list.join ' '}" if options[:verbose]
    return if options[:noop]

    list.each do |dir|
      fu_mkdir dir, options[:mode]
    end
  end
  module_function :mkdir

  OPT_TABLE['mkdir'] = [:mode, :noop, :verbose]

  def mkdir_p(list, options = {})
    fu_check_options options, OPT_TABLE['mkdir_p']
    list = fu_list(list)
    fu_output_message "mkdir -p #{options[:mode] ? ('-m %03o ' % options[:mode]) : ''}#{list.join ' '}" if options[:verbose]
    return *list if options[:noop]

    list.map {|path| remove_tailing_slash(path)}.each do |path|
      begin
        fu_mkdir path, options[:mode]
        next
      rescue SystemCallError
        next if File.directory?(path)
      end

      stack = []
      until path == stack.last   # dirname("/")=="/", dirname("C:/")=="C:/"
        stack.push path
        path = File.dirname(path)
      end
      stack.reverse_each do |dir|
        begin
          fu_mkdir dir, options[:mode]
        rescue SystemCallError
          raise unless File.directory?(dir)
        end
      end
    end

    return *list
  end
  module_function :mkdir_p

  alias mkpath    mkdir_p
  alias makedirs  mkdir_p
  module_function :mkpath
  module_function :makedirs

  OPT_TABLE['mkdir_p']  =
  OPT_TABLE['mkpath']   =
  OPT_TABLE['makedirs'] = [:mode, :noop, :verbose]

  def fu_mkdir(path, mode)   #:nodoc:
    path = remove_tailing_slash(path)
    if mode
      Dir.mkdir path, mode
      File.chmod mode, path
    else
      Dir.mkdir path
    end
  end
  private_module_function :fu_mkdir

  def rmdir(list, options = {})
    fu_check_options options, OPT_TABLE['rmdir']
    list = fu_list(list)
    parents = options[:parents]
    fu_output_message "rmdir #{parents ? '-p ' : ''}#{list.join ' '}" if options[:verbose]
    return if options[:noop]
    list.each do |dir|
      begin
        Dir.rmdir(dir = remove_tailing_slash(dir))
        if parents
          until (parent = File.dirname(dir)) == '.' or parent == dir
            dir = parent
            Dir.rmdir(dir)
          end
        end
      rescue Errno::ENOTEMPTY, Errno::EEXIST, Errno::ENOENT
      end
    end
  end
  module_function :rmdir

  OPT_TABLE['rmdir'] = [:parents, :noop, :verbose]

  def ln(src, dest, options = {})
    fu_check_options options, OPT_TABLE['ln']
    fu_output_message "ln#{options[:force] ? ' -f' : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
    return if options[:noop]
    fu_each_src_dest0(src, dest) do |s,d|
      remove_file d, true if options[:force]
      File.link s, d
    end
  end
  module_function :ln

  alias link ln
  module_function :link

  OPT_TABLE['ln']   =
  OPT_TABLE['link'] = [:force, :noop, :verbose]

  def ln_s(src, dest, options = {})
    fu_check_options options, OPT_TABLE['ln_s']
    fu_output_message "ln -s#{options[:force] ? 'f' : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
    return if options[:noop]
    fu_each_src_dest0(src, dest) do |s,d|
      remove_file d, true if options[:force]
      File.symlink s, d
    end
  end
  module_function :ln_s

  alias symlink ln_s
  module_function :symlink

  OPT_TABLE['ln_s']    =
  OPT_TABLE['symlink'] = [:force, :noop, :verbose]

  def ln_sf(src, dest, options = {})
    fu_check_options options, OPT_TABLE['ln_sf']
    options = options.dup
    options[:force] = true
    ln_s src, dest, options
  end
  module_function :ln_sf

  OPT_TABLE['ln_sf'] = [:noop, :verbose]

  def cp(src, dest, options = {})
    fu_check_options options, OPT_TABLE['cp']
    fu_output_message "cp#{options[:preserve] ? ' -p' : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
    return if options[:noop]
    fu_each_src_dest(src, dest) do |s, d|
      copy_file s, d, options[:preserve]
    end
  end
  module_function :cp

  alias copy cp
  module_function :copy

  OPT_TABLE['cp']   =
  OPT_TABLE['copy'] = [:preserve, :noop, :verbose]

  def cp_r(src, dest, options = {})
    fu_check_options options, OPT_TABLE['cp_r']
    fu_output_message "cp -r#{options[:preserve] ? 'p' : ''}#{options[:remove_destination] ? ' --remove-destination' : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
    return if options[:noop]
    options = options.dup
    options[:dereference_root] = true unless options.key?(:dereference_root)
    fu_each_src_dest(src, dest) do |s, d|
      copy_entry s, d, options[:preserve], options[:dereference_root], options[:remove_destination]
    end
  end
  module_function :cp_r

  OPT_TABLE['cp_r'] = [:preserve, :noop, :verbose,
                       :dereference_root, :remove_destination]

  def copy_entry(src, dest, preserve = false, dereference_root = false, remove_destination = false)
    Entry_.new(src, nil, dereference_root).wrap_traverse(proc do |ent|
      destent = Entry_.new(dest, ent.rel, false)
      File.unlink destent.path if remove_destination && File.file?(destent.path)
      ent.copy destent.path
    end, proc do |ent|
      destent = Entry_.new(dest, ent.rel, false)
      ent.copy_metadata destent.path if preserve
    end)
  end
  module_function :copy_entry

  def copy_file(src, dest, preserve = false, dereference = true)
    ent = Entry_.new(src, nil, dereference)
    ent.copy_file dest
    ent.copy_metadata dest if preserve
  end
  module_function :copy_file

  def copy_stream(src, dest)
    IO.copy_stream(src, dest)
  end
  module_function :copy_stream

  def mv(src, dest, options = {})
    fu_check_options options, OPT_TABLE['mv']
    fu_output_message "mv#{options[:force] ? ' -f' : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
    return if options[:noop]
    fu_each_src_dest(src, dest) do |s, d|
      destent = Entry_.new(d, nil, true)
      begin
        if destent.exist?
          if destent.directory?
            raise Errno::EEXIST, d
          else
            destent.remove_file if rename_cannot_overwrite_file?
          end
        end
        begin
          File.rename s, d
        rescue Errno::EXDEV
          copy_entry s, d, true
          if options[:secure]
            remove_entry_secure s, options[:force]
          else
            remove_entry s, options[:force]
          end
        end
      rescue SystemCallError
        raise unless options[:force]
      end
    end
  end
  module_function :mv

  alias move mv
  module_function :move

  OPT_TABLE['mv']   =
  OPT_TABLE['move'] = [:force, :noop, :verbose, :secure]

  def rename_cannot_overwrite_file?   #:nodoc:
    /cygwin|mswin|mingw|bccwin|emx/ =~ RUBY_PLATFORM
  end
  private_module_function :rename_cannot_overwrite_file?

  def rm(list, options = {})
    fu_check_options options, OPT_TABLE['rm']
    list = fu_list(list)
    fu_output_message "rm#{options[:force] ? ' -f' : ''} #{list.join ' '}" if options[:verbose]
    return if options[:noop]

    list.each do |path|
      remove_file path, options[:force]
    end
  end
  module_function :rm

  alias remove rm
  module_function :remove

  OPT_TABLE['rm']     =
  OPT_TABLE['remove'] = [:force, :noop, :verbose]

  def rm_f(list, options = {})
    fu_check_options options, OPT_TABLE['rm_f']
    options = options.dup
    options[:force] = true
    rm list, options
  end
  module_function :rm_f

  alias safe_unlink rm_f
  module_function :safe_unlink

  OPT_TABLE['rm_f']        =
  OPT_TABLE['safe_unlink'] = [:noop, :verbose]

  def rm_r(list, options = {})
    fu_check_options options, OPT_TABLE['rm_r']
    list = fu_list(list)
    fu_output_message "rm -r#{options[:force] ? 'f' : ''} #{list.join ' '}" if options[:verbose]
    return if options[:noop]
    list.each do |path|
      if options[:secure]
        remove_entry_secure path, options[:force]
      else
        remove_entry path, options[:force]
      end
    end
  end
  module_function :rm_r

  OPT_TABLE['rm_r'] = [:force, :noop, :verbose, :secure]

  def rm_rf(list, options = {})
    fu_check_options options, OPT_TABLE['rm_rf']
    options = options.dup
    options[:force] = true
    rm_r list, options
  end
  module_function :rm_rf

  alias rmtree rm_rf
  module_function :rmtree

  OPT_TABLE['rm_rf']  =
  OPT_TABLE['rmtree'] = [:noop, :verbose, :secure]

  def remove_entry_secure(path, force = false)
    unless fu_have_symlink?
      remove_entry path, force
      return
    end
    fullpath = File.expand_path(path)
    st = File.lstat(fullpath)
    unless st.directory?
      File.unlink fullpath
      return
    end
    parent_st = File.stat(File.dirname(fullpath))
    unless parent_st.world_writable?
      remove_entry path, force
      return
    end
    unless parent_st.sticky?
      raise ArgumentError, "parent directory is world writable, FileUtils#remove_entry_secure does not work; abort: #{path.inspect} (parent directory mode #{'%o' % parent_st.mode})"
    end
    euid = Process.euid
    File.open(fullpath + '/.') {|f|
      unless fu_stat_identical_entry?(st, f.stat)
        File.unlink fullpath
        return
      end
      f.chown euid, -1
      f.chmod 0700
      unless fu_stat_identical_entry?(st, File.lstat(fullpath))
        File.unlink fullpath
        return
      end
    }
    root = Entry_.new(path)
    root.preorder_traverse do |ent|
      if ent.directory?
        ent.chown euid, -1
        ent.chmod 0700
      end
    end
    root.postorder_traverse do |ent|
      begin
        ent.remove
      rescue
        raise unless force
      end
    end
  rescue
    raise unless force
  end
  module_function :remove_entry_secure

  def fu_have_symlink?   #:nodoc:
    File.symlink nil, nil
  rescue NotImplementedError
    return false
  rescue TypeError
    return true
  end
  private_module_function :fu_have_symlink?

  def fu_stat_identical_entry?(a, b)   #:nodoc:
    a.dev == b.dev and a.ino == b.ino
  end
  private_module_function :fu_stat_identical_entry?

  def remove_entry(path, force = false)
    Entry_.new(path).postorder_traverse do |ent|
      begin
        ent.remove
      rescue
        raise unless force
      end
    end
  rescue
    raise unless force
  end
  module_function :remove_entry

  def remove_file(path, force = false)
    Entry_.new(path).remove_file
  rescue
    raise unless force
  end
  module_function :remove_file

  def remove_dir(path, force = false)
    remove_entry path, force   # FIXME?? check if it is a directory
  end
  module_function :remove_dir

  def compare_file(a, b)
    return false unless File.size(a) == File.size(b)
    File.open(a, 'rb') {|fa|
      File.open(b, 'rb') {|fb|
        return compare_stream(fa, fb)
      }
    }
  end
  module_function :compare_file

  alias identical? compare_file
  alias cmp compare_file
  module_function :identical?
  module_function :cmp

  def compare_stream(a, b)
    bsize = fu_stream_blksize(a, b)
    sa = ""
    sb = ""
    begin
      a.read(bsize, sa)
      b.read(bsize, sb)
      return true if sa.empty? && sb.empty?
    end while sa == sb
    false
  end
  module_function :compare_stream

  def install(src, dest, options = {})
    fu_check_options options, OPT_TABLE['install']
    fu_output_message "install -c#{options[:preserve] && ' -p'}#{options[:mode] ? (' -m 0%o' % options[:mode]) : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
    return if options[:noop]
    fu_each_src_dest(src, dest) do |s, d|
      st = File.stat(s)
      unless File.exist?(d) and compare_file(s, d)
        remove_file d, true
        copy_file s, d
        File.utime st.atime, st.mtime, d if options[:preserve]
        File.chmod options[:mode], d if options[:mode]
      end
    end
  end
  module_function :install

  OPT_TABLE['install'] = [:mode, :preserve, :noop, :verbose]

  def user_mask(target)  #:nodoc:
    target.each_char.inject(0) do |mask, chr|
      case chr
      when "u"
        mask | 04700
      when "g"
        mask | 02070
      when "o"
        mask | 01007
      when "a"
        mask | 07777
      else
        raise ArgumentError, "invalid `who' symbol in file mode: #{chr}"
      end
    end
  end
  private_module_function :user_mask

  def apply_mask(mode, user_mask, op, mode_mask)
    case op
    when '='
      (mode & ~user_mask) | (user_mask & mode_mask)
    when '+'
      mode | (user_mask & mode_mask)
    when '-'
      mode & ~(user_mask & mode_mask)
    end
  end
  private_module_function :apply_mask

  def symbolic_modes_to_i(mode_sym, path)  #:nodoc:
    mode_sym.split(/,/).inject(File.stat(path).mode & 07777) do |current_mode, clause|
      target, *actions = clause.split(/([=+-])/)
      raise ArgumentError, "invalid file mode: #{mode_sym}" if actions.empty?
      target = 'a' if target.empty?
      user_mask = user_mask(target)
      actions.each_slice(2) do |op, perm|
        need_apply = op == '='
        mode_mask = (perm || '').each_char.inject(0) do |mask, chr|
          case chr
          when "r"
            mask | 0444
          when "w"
            mask | 0222
          when "x"
            mask | 0111
          when "X"
            if FileTest.directory? path
              mask | 0111
            else
              mask
            end
          when "s"
            mask | 06000
          when "t"
            mask | 01000
          when "u", "g", "o"
            if mask.nonzero?
              current_mode = apply_mask(current_mode, user_mask, op, mask)
            end
            need_apply = false
            copy_mask = user_mask(chr)
            (current_mode & copy_mask) / (copy_mask & 0111) * (user_mask & 0111)
          else
            raise ArgumentError, "invalid `perm' symbol in file mode: #{chr}"
          end
        end

        if mode_mask.nonzero? || need_apply
          current_mode = apply_mask(current_mode, user_mask, op, mode_mask)
        end
      end
      current_mode
    end
  end
  private_module_function :symbolic_modes_to_i

  def fu_mode(mode, path)  #:nodoc:
    mode.is_a?(String) ? symbolic_modes_to_i(mode, path) : mode
  end
  private_module_function :fu_mode

  def mode_to_s(mode)  #:nodoc:
    mode.is_a?(String) ? mode : "%o" % mode
  end
  private_module_function :mode_to_s


  def chmod(mode, list, options = {})
    fu_check_options options, OPT_TABLE['chmod']
    list = fu_list(list)
    fu_output_message sprintf('chmod %s %s', mode_to_s(mode), list.join(' ')) if options[:verbose]
    return if options[:noop]
    list.each do |path|
      Entry_.new(path).chmod(fu_mode(mode, path))
    end
  end
  module_function :chmod

  OPT_TABLE['chmod'] = [:noop, :verbose]

  def chmod_R(mode, list, options = {})
    fu_check_options options, OPT_TABLE['chmod_R']
    list = fu_list(list)
    fu_output_message sprintf('chmod -R%s %s %s',
                              (options[:force] ? 'f' : ''),
                              mode_to_s(mode), list.join(' ')) if options[:verbose]
    return if options[:noop]
    list.each do |root|
      Entry_.new(root).traverse do |ent|
        begin
          ent.chmod(fu_mode(mode, ent.path))
        rescue
          raise unless options[:force]
        end
      end
    end
  end
  module_function :chmod_R

  OPT_TABLE['chmod_R'] = [:noop, :verbose, :force]

  def chown(user, group, list, options = {})
    fu_check_options options, OPT_TABLE['chown']
    list = fu_list(list)
    fu_output_message sprintf('chown %s %s',
                              (group ? "#{user}:#{group}" : user || ':'),
                              list.join(' ')) if options[:verbose]
    return if options[:noop]
    uid = fu_get_uid(user)
    gid = fu_get_gid(group)
    list.each do |path|
      Entry_.new(path).chown uid, gid
    end
  end
  module_function :chown

  OPT_TABLE['chown'] = [:noop, :verbose]

  def chown_R(user, group, list, options = {})
    fu_check_options options, OPT_TABLE['chown_R']
    list = fu_list(list)
    fu_output_message sprintf('chown -R%s %s %s',
                              (options[:force] ? 'f' : ''),
                              (group ? "#{user}:#{group}" : user || ':'),
                              list.join(' ')) if options[:verbose]
    return if options[:noop]
    uid = fu_get_uid(user)
    gid = fu_get_gid(group)
    list.each do |root|
      Entry_.new(root).traverse do |ent|
        begin
          ent.chown uid, gid
        rescue
          raise unless options[:force]
        end
      end
    end
  end
  module_function :chown_R

  OPT_TABLE['chown_R'] = [:noop, :verbose, :force]

  begin
    require 'etc'
  rescue LoadError # rescue LoadError for miniruby
  end

  def fu_get_uid(user)   #:nodoc:
    return nil unless user
    case user
    when Integer
      user
    when /\A\d+\z/
      user.to_i
    else
      Etc.getpwnam(user) ? Etc.getpwnam(user).uid : nil
    end
  end
  private_module_function :fu_get_uid

  def fu_get_gid(group)   #:nodoc:
    return nil unless group
    case group
    when Integer
      group
    when /\A\d+\z/
      group.to_i
    else
      Etc.getgrnam(group) ? Etc.getgrnam(group).gid : nil
    end
  end
  private_module_function :fu_get_gid

  def touch(list, options = {})
    fu_check_options options, OPT_TABLE['touch']
    list = fu_list(list)
    nocreate = options[:nocreate]
    t = options[:mtime]
    if options[:verbose]
      fu_output_message "touch #{nocreate ? '-c ' : ''}#{t ? t.strftime('-t %Y%m%d%H%M.%S ') : ''}#{list.join ' '}"
    end
    return if options[:noop]
    list.each do |path|
      created = nocreate
      begin
        File.utime(t, t, path)
      rescue Errno::ENOENT
        raise if created
        File.open(path, 'a') {
          ;
        }
        created = true
        retry if t
      end
    end
  end
  module_function :touch

  OPT_TABLE['touch'] = [:noop, :verbose, :mtime, :nocreate]

  private

  module StreamUtils_
    private

    def fu_windows?
      /mswin|mingw|bccwin|emx/ =~ RUBY_PLATFORM
    end

    def fu_copy_stream0(src, dest, blksize = nil)   #:nodoc:
      IO.copy_stream(src, dest)
    end

    def fu_stream_blksize(*streams)
      streams.each do |s|
        next unless s.respond_to?(:stat)
        size = fu_blksize(s.stat)
        return size if size
      end
      fu_default_blksize()
    end

    def fu_blksize(st)
      s = st.blksize
      return nil unless s
      return nil if s == 0
      s
    end

    def fu_default_blksize
      1024
    end
  end

  include StreamUtils_
  extend StreamUtils_

  class Entry_   #:nodoc: internal use only
    include StreamUtils_

    def initialize(a, b = nil, deref = false)
      @prefix = @rel = @path = nil
      if b
        @prefix = a
        @rel = b
      else
        @path = a
      end
      @deref = deref
      @stat = nil
      @lstat = nil
    end

    def inspect
      "\#<#{self.class} #{path()}>"
    end

    def path
      if @path
        File.path(@path)
      else
        join(@prefix, @rel)
      end
    end

    def prefix
      @prefix || @path
    end

    def rel
      @rel
    end

    def dereference?
      @deref
    end

    def exist?
      begin
        lstat
        true
      rescue Errno::ENOENT
        false
      end
    end

    def file?
      s = lstat!
      s and s.file?
    end

    def directory?
      s = lstat!
      s and s.directory?
    end

    def symlink?
      s = lstat!
      s and s.symlink?
    end

    def chardev?
      s = lstat!
      s and s.chardev?
    end

    def blockdev?
      s = lstat!
      s and s.blockdev?
    end

    def socket?
      s = lstat!
      s and s.socket?
    end

    def pipe?
      s = lstat!
      s and s.pipe?
    end

    S_IF_DOOR = 0xD000

    def door?
      s = lstat!
      s and (s.mode & 0xF000 == S_IF_DOOR)
    end

    def entries
      opts = {}
      opts[:encoding] = ::Encoding::UTF_8 if fu_windows?
      Dir.entries(path(), opts)\
          .reject {|n| n == '.' or n == '..' }\
          .map {|n| Entry_.new(prefix(), join(rel(), n.untaint)) }
    end

    def stat
      return @stat if @stat
      if lstat() and lstat().symlink?
        @stat = File.stat(path())
      else
        @stat = lstat()
      end
      @stat
    end

    def stat!
      return @stat if @stat
      if lstat! and lstat!.symlink?
        @stat = File.stat(path())
      else
        @stat = lstat!
      end
      @stat
    rescue SystemCallError
      nil
    end

    def lstat
      if dereference?
        @lstat ||= File.stat(path())
      else
        @lstat ||= File.lstat(path())
      end
    end

    def lstat!
      lstat()
    rescue SystemCallError
      nil
    end

    def chmod(mode)
      if symlink?
        File.lchmod mode, path() if have_lchmod?
      else
        File.chmod mode, path()
      end
    end

    def chown(uid, gid)
      if symlink?
        File.lchown uid, gid, path() if have_lchown?
      else
        File.chown uid, gid, path()
      end
    end

    def copy(dest)
      case
      when file?
        copy_file dest
      when directory?
        if !File.exist?(dest) and descendant_directory?(dest, path)
          raise ArgumentError, "cannot copy directory %s to itself %s" % [path, dest]
        end
        begin
          Dir.mkdir dest
        rescue
          raise unless File.directory?(dest)
        end
      when symlink?
        File.symlink File.readlink(path()), dest
      when chardev?
        raise "cannot handle device file" unless File.respond_to?(:mknod)
        mknod dest, ?c, 0666, lstat().rdev
      when blockdev?
        raise "cannot handle device file" unless File.respond_to?(:mknod)
        mknod dest, ?b, 0666, lstat().rdev
      when socket?
        raise "cannot handle socket" unless File.respond_to?(:mknod)
        mknod dest, nil, lstat().mode, 0
      when pipe?
        raise "cannot handle FIFO" unless File.respond_to?(:mkfifo)
        mkfifo dest, 0666
      when door?
        raise "cannot handle door: #{path()}"
      else
        raise "unknown file type: #{path()}"
      end
    end

    def copy_file(dest)
      File.open(path()) do |s|
        File.open(dest, 'wb', s.stat.mode) do |f|
          IO.copy_stream(s, f)
        end
      end
    end

    def copy_metadata(path)
      st = lstat()
      if !st.symlink?
        File.utime st.atime, st.mtime, path
      end
      begin
        if st.symlink?
          begin
            File.lchown st.uid, st.gid, path
          rescue NotImplementedError
          end
        else
          File.chown st.uid, st.gid, path
        end
      rescue Errno::EPERM
        if st.symlink?
          begin
            File.lchmod st.mode & 01777, path
          rescue NotImplementedError
          end
        else
          File.chmod st.mode & 01777, path
        end
      else
        if st.symlink?
          begin
            File.lchmod st.mode, path
          rescue NotImplementedError
          end
        else
          File.chmod st.mode, path
        end
      end
    end

    def remove
      if directory?
        remove_dir1
      else
        remove_file
      end
    end

    def remove_dir1
      platform_support {
        Dir.rmdir path().chomp(?/)
      }
    end

    def remove_file
      platform_support {
        File.unlink path
      }
    end

    def platform_support
      return yield unless fu_windows?
      first_time_p = true
      begin
        yield
      rescue Errno::ENOENT
        raise
      rescue => err
        if first_time_p
          first_time_p = false
          begin
            File.chmod 0700, path()   # Windows does not have symlink
            retry
          rescue SystemCallError
          end
        end
        raise err
      end
    end

    def preorder_traverse
      stack = [self]
      while ent = stack.pop
        yield ent
        stack.concat ent.entries.reverse if ent.directory?
      end
    end

    alias traverse preorder_traverse

    def postorder_traverse
      if directory?
        entries().each do |ent|
          ent.postorder_traverse do |e|
            yield e
          end
        end
      end
    ensure
      yield self
    end

    def wrap_traverse(pre, post)
      pre.call self
      if directory?
        entries.each do |ent|
          ent.wrap_traverse pre, post
        end
      end
      post.call self
    end

    private

    $fileutils_rb_have_lchmod = nil

    def have_lchmod?
      if $fileutils_rb_have_lchmod == nil
        $fileutils_rb_have_lchmod = check_have_lchmod?
      end
      $fileutils_rb_have_lchmod
    end

    def check_have_lchmod?
      return false unless File.respond_to?(:lchmod)
      File.lchmod 0
      return true
    rescue NotImplementedError
      return false
    end

    $fileutils_rb_have_lchown = nil

    def have_lchown?
      if $fileutils_rb_have_lchown == nil
        $fileutils_rb_have_lchown = check_have_lchown?
      end
      $fileutils_rb_have_lchown
    end

    def check_have_lchown?
      return false unless File.respond_to?(:lchown)
      File.lchown nil, nil
      return true
    rescue NotImplementedError
      return false
    end

    def join(dir, base)
      return File.path(dir) if not base or base == '.'
      return File.path(base) if not dir or dir == '.'
      File.join(dir, base)
    end

    if File::ALT_SEPARATOR
      DIRECTORY_TERM = "(?=[/#{Regexp.quote(File::ALT_SEPARATOR)}]|\\z)".freeze
    else
      DIRECTORY_TERM = "(?=/|\\z)".freeze
    end
    SYSCASE = File::FNM_SYSCASE.nonzero? ? "-i" : ""

    def descendant_directory?(descendant, ascendant)
      /\A(?#{SYSCASE}:#{Regexp.quote(ascendant)})#{DIRECTORY_TERM}/ =~ File.dirname(descendant)
    end
  end   # class Entry_

  def fu_list(arg)   #:nodoc:
    [arg].flatten.map {|path| File.path(path) }
  end
  private_module_function :fu_list

  def fu_each_src_dest(src, dest)   #:nodoc:
    fu_each_src_dest0(src, dest) do |s, d|
      raise ArgumentError, "same file: #{s} and #{d}" if fu_same?(s, d)
      yield s, d
    end
  end
  private_module_function :fu_each_src_dest

  def fu_each_src_dest0(src, dest)   #:nodoc:
    if tmp = Array.try_convert(src)
      tmp.each do |s|
        s = File.path(s)
        yield s, File.join(dest, File.basename(s))
      end
    else
      src = File.path(src)
      if File.directory?(dest)
        yield src, File.join(dest, File.basename(src))
      else
        yield src, File.path(dest)
      end
    end
  end
  private_module_function :fu_each_src_dest0

  def fu_same?(a, b)   #:nodoc:
    File.identical?(a, b)
  end
  private_module_function :fu_same?

  def fu_check_options(options, optdecl)   #:nodoc:
    h = options.dup
    optdecl.each do |opt|
      h.delete opt
    end
    raise ArgumentError, "no such option: #{h.keys.join(' ')}" unless h.empty?
  end
  private_module_function :fu_check_options

  def fu_update_option(args, new)   #:nodoc:
    if tmp = Hash.try_convert(args.last)
      args[-1] = tmp.dup.update(new)
    else
      args.push new
    end
    args
  end
  private_module_function :fu_update_option

  @fileutils_output = $stderr
  @fileutils_label  = ''

  def fu_output_message(msg)   #:nodoc:
    @fileutils_output ||= $stderr
    @fileutils_label  ||= ''
    @fileutils_output.puts @fileutils_label + msg
  end
  private_module_function :fu_output_message

  def FileUtils.commands
    OPT_TABLE.keys
  end

  def FileUtils.options
    OPT_TABLE.values.flatten.uniq.map {|sym| sym.to_s }
  end

  def FileUtils.have_option?(mid, opt)
    li = OPT_TABLE[mid.to_s] or raise ArgumentError, "no such method: #{mid}"
    li.include?(opt)
  end

  def FileUtils.options_of(mid)
    OPT_TABLE[mid.to_s].map {|sym| sym.to_s }
  end

  def FileUtils.collect_method(opt)
    OPT_TABLE.keys.select {|m| OPT_TABLE[m].include?(opt) }
  end

  LOW_METHODS = singleton_methods(false) - collect_method(:noop).map(&:intern)
  module LowMethods
    #nodyna <module_eval-1966> <not yet classified>
    module_eval("private\n" + ::FileUtils::LOW_METHODS.map {|name| "def #{name}(*)end"}.join("\n"),
                __FILE__, __LINE__)
  end

  METHODS = singleton_methods() - [:private_module_function,
      :commands, :options, :have_option?, :options_of, :collect_method]

  module Verbose
    include FileUtils
    @fileutils_output  = $stderr
    @fileutils_label   = ''
    ::FileUtils.collect_method(:verbose).each do |name|
      #nodyna <module_eval-1967> <not yet classified>
      module_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(*args)
          super(*fu_update_option(args, :verbose => true))
        end
        private :#{name}
      EOS
    end
    extend self
    class << self
      ::FileUtils::METHODS.each do |m|
        public m
      end
    end
  end

  module NoWrite
    include FileUtils
    include LowMethods
    @fileutils_output  = $stderr
    @fileutils_label   = ''
    ::FileUtils.collect_method(:noop).each do |name|
      #nodyna <module_eval-1968> <not yet classified>
      module_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(*args)
          super(*fu_update_option(args, :noop => true))
        end
        private :#{name}
      EOS
    end
    extend self
    class << self
      ::FileUtils::METHODS.each do |m|
        public m
      end
    end
  end

  module DryRun
    include FileUtils
    include LowMethods
    @fileutils_output  = $stderr
    @fileutils_label   = ''
    ::FileUtils.collect_method(:noop).each do |name|
      #nodyna <module_eval-1969> <not yet classified>
      module_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{name}(*args)
          super(*fu_update_option(args, :noop => true, :verbose => true))
        end
        private :#{name}
      EOS
    end
    extend self
    class << self
      ::FileUtils::METHODS.each do |m|
        public m
      end
    end
  end

end
