require "fileutils"
require "tmpdir"

module FileUtils
  def mktemp(prefix = name)
    prev = pwd
    tmp  = Dir.mktmpdir(prefix, HOMEBREW_TEMP)

    begin
      cd(tmp)

      begin
        yield
      ensure
        cd(prev)
      end
    ensure
      ignore_interrupts { rm_rf(tmp) }
    end
  end
  module_function :mktemp

  alias_method :old_mkdir, :mkdir

  def mkdir(name, &_block)
    old_mkdir(name)
    if block_given?
      chdir name do
        yield
      end
    end
  end
  module_function :mkdir

  if RUBY_VERSION < "2.0.0"
    class Entry_
      alias_method :old_copy_metadata, :copy_metadata
      def copy_metadata(path)
        st = lstat
        unless st.symlink?
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
    end
  end

  def scons(*args)
    system Formulary.factory("scons").opt_bin/"scons", *args
  end

  def rake(*args)
    system RUBY_BIN/"rake", *args
  end

  if method_defined?(:ruby)
    alias_method :old_ruby, :ruby
  end

  def ruby(*args)
    system RUBY_PATH, *args
  end

  def xcodebuild(*args)
    removed = ENV.remove_cc_etc
    system "xcodebuild", *args
  ensure
    ENV.update(removed)
  end
end
