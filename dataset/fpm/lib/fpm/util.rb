require "fpm/namespace"
require "childprocess"
require "ffi"

module FPM::Util
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  begin
    attach_function :mknod, :mknod, [:string, :uint, :ulong], :int
  rescue FFI::NotFoundError
    attach_function :xmknod, :__xmknod, [:int, :string, :uint, :pointer], :int
  end

  class ExecutableNotFound < StandardError; end

  class ProcessFailed < StandardError; end

  def program_in_path?(program)
    return false unless ENV['PATH']
    envpath = ENV["PATH"].split(":")
    return envpath.select { |p| File.executable?(File.join(p, program)) }.any?
  end # def program_in_path

  def program_exists?(program)
    return program_in_path?(program) if !program.include?("/")
    return File.executable?(program)
  end # def program_exists?

  def default_shell
    shell = ENV["SHELL"]
    return "/bin/sh" if shell.nil? || shell.empty?
    return shell
  end

  def safesystem(*args)
    if args.size == 1
      args = [ default_shell, "-c", args[0] ]
    end
    program = args[0]

    if !program_exists?(program)
      raise ExecutableNotFound.new(program)
    end

    logger.debug("Running command", :args => args)

    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe

    process           = ChildProcess.build(*args)
    process.io.stdout = stdout_w
    process.io.stderr = stderr_w

    process.start
    stdout_w.close; stderr_w.close
    logger.debug('Process is running', :pid => process.pid)
    logger.pipe(stdout_r => :info, stderr_r => :info)

    process.wait
    success = (process.exit_code == 0)

    if !success
      raise ProcessFailed.new("#{program} failed (exit code #{process.exit_code})" \
                              ". Full command was:#{args.inspect}")
    end
    return success
  end # def safesystem

  def safesystemout(*args)
    if args.size == 1
      args = [ ENV["SHELL"], "-c", args[0] ]
    end
    program = args[0]

    if !program.include?("/") and !program_in_path?(program)
      raise ExecutableNotFound.new(program)
    end

    logger.debug("Running command", :args => args)

    stdout_r, stdout_w = IO.pipe
    stderr_r, stderr_w = IO.pipe

    process           = ChildProcess.build(*args)
    process.io.stdout = stdout_w
    process.io.stderr = stderr_w

    process.start
    stdout_w.close; stderr_w.close
    stdout_r_str = stdout_r.read
    stdout_r.close; stderr_r.close
    logger.debug("Process is running", :pid => process.pid)

    process.wait
    success = (process.exit_code == 0)

    if !success
      raise ProcessFailed.new("#{program} failed (exit code #{process.exit_code})" \
                              ". Full command was:#{args.inspect}")
    end

    return stdout_r_str
  end # def safesystemout

  def tar_cmd
    case %x{uname -s}.chomp
    when "SunOS"
      return "gtar"
    when "Darwin"
      ["gnutar", "gtar"].each do |tar|
        system("#{tar} > /dev/null 2> /dev/null")
        return tar unless $?.exitstatus == 127
      end
    else
      return "tar"
    end
  end # def tar_cmd

  def with(value, &block)
    block.call(value)
  end # def with

  def mknod_w(path, mode, dev)
    rc = -1
    case %x{uname -s}.chomp
    when 'Linux'
      rc = xmknod(0, path, mode, FFI::MemoryPointer.new(dev))
    else
      rc = mknod(path, mode, dev)
    end
    rc
  end

  def copy_metadata(source, destination)
    source_stat = File::lstat(source)
    dest_stat = File::lstat(destination)

    return if source_stat.ino == dest_stat.ino || dest_stat.symlink?

    File.utime(source_stat.atime, source_stat.mtime, destination)
    mode = source_stat.mode
    begin
      File.lchown(source_stat.uid, source_stat.gid, destination)
    rescue Errno::EPERM
      mode &= 01777
    end

    unless source_stat.symlink?
      File.chmod(mode, destination)
    end
  end # def copy_metadata


  def copy_entry(src, dst, preserve=false, remove_destination=false)
    case File.ftype(src)
    when 'fifo', 'characterSpecial', 'blockSpecial', 'socket'
      st = File.stat(src)
      rc = mknod_w(dst, st.mode, st.dev)
      raise SystemCallError.new("mknod error", FFI.errno) if rc == -1
    when 'directory'
      FileUtils.mkdir(dst) unless File.exists? dst
    else
      st = File.lstat(src)
      known_entry = copied_entries[[st.dev, st.ino]]
      if known_entry
        FileUtils.ln(known_entry, dst)
      else
        FileUtils.copy_entry(src, dst, preserve=preserve,
                             remove_destination=remove_destination)
        copied_entries[[st.dev, st.ino]] = dst
      end
    end # else...
  end # def copy_entry

  def copied_entries
    return @copied_entries ||= {}
  end # def copied_entries

  def expand_pessimistic_constraints(constraint)
    name, op, version = constraint.split(/\s+/)

    if op == '~>'

      new_lower_constraint = "#{name} >= #{version}"

      version_components = version.split('.').collect { |v| v.to_i }

      version_prefix = version_components[0..-3].join('.')
      portion_to_work_with = version_components.last(2)

      prefix = ''
      unless version_prefix.empty?
        prefix = version_prefix + '.'
      end

      one_to_increment = portion_to_work_with[0].to_i
      incremented = one_to_increment + 1

      new_version = ''+ incremented.to_s + '.0'

      upper_version = prefix + new_version

      new_upper_constraint = "#{name} < #{upper_version}"

      return [new_lower_constraint,new_upper_constraint]
    else
      return [constraint]
    end
  end #def expand_pesimistic_constraints

  def logger
    @logger ||= Cabin::Channel.get
  end # def logger
end # module FPM::Util
