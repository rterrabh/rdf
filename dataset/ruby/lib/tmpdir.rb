
require 'fileutils'
begin
  require 'etc.so'
rescue LoadError # rescue LoadError for miniruby
end

class Dir

  @@systmpdir ||= defined?(Etc.systmpdir) ? Etc.systmpdir : '/tmp'


  def self.tmpdir
    if $SAFE > 0
      @@systmpdir
    else
      tmp = nil
      [ENV['TMPDIR'], ENV['TMP'], ENV['TEMP'], @@systmpdir, '/tmp', '.'].each do |dir|
        next if !dir
        dir = File.expand_path(dir)
        if stat = File.stat(dir) and stat.directory? and stat.writable? and
            (!stat.world_writable? or stat.sticky?)
          tmp = dir
          break
        end rescue nil
      end
      raise ArgumentError, "could not find a temporary directory" unless tmp
      tmp
    end
  end

  def Dir.mktmpdir(prefix_suffix=nil, *rest)
    path = Tmpname.create(prefix_suffix || "d", *rest) {|n| mkdir(n, 0700)}
    if block_given?
      begin
        yield path
      ensure
        stat = File.stat(File.dirname(path))
        if stat.world_writable? and !stat.sticky?
          raise ArgumentError, "parent directory is world writable but not sticky"
        end
        FileUtils.remove_entry path
      end
    else
      path
    end
  end

  module Tmpname # :nodoc:
    module_function

    def tmpdir
      Dir.tmpdir
    end

    def make_tmpname((prefix, suffix), n)
      prefix = (String.try_convert(prefix) or
                raise ArgumentError, "unexpected prefix: #{prefix.inspect}")
      suffix &&= (String.try_convert(suffix) or
                  raise ArgumentError, "unexpected suffix: #{suffix.inspect}")
      t = Time.now.strftime("%Y%m%d")
      path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
      path << "-#{n}" if n
      path << suffix if suffix
      path
    end

    def create(basename, tmpdir=nil, max_try: nil, **opts)
      if $SAFE > 0 and tmpdir.tainted?
        tmpdir = '/tmp'
      else
        tmpdir ||= tmpdir()
      end
      n = nil
      begin
        path = File.join(tmpdir, make_tmpname(basename, n))
        yield(path, n, opts)
      rescue Errno::EEXIST
        n ||= 0
        n += 1
        retry if !max_try or n < max_try
        raise "cannot generate temporary name using `#{basename}' under `#{tmpdir}'"
      end
      path
    end
  end
end
