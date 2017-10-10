module Jekyll
  class StaticFile
    @@mtimes = Hash.new

    attr_reader :relative_path, :extname

    def initialize(site, base, dir, name, collection = nil)
      @site = site
      @base = base
      @dir  = dir
      @name = name
      @collection = collection
      @relative_path = File.join(*[@dir, @name].compact)
      @extname = File.extname(@name)
    end

    def path
      File.join(*[@base, @dir, @name].compact)
    end

    def destination(dest)
      @site.in_dest_dir(*[dest, destination_rel_dir, @name].compact)
    end

    def destination_rel_dir
      if @collection
        @dir.gsub(/\A_/, '')
      else
        @dir
      end
    end

    def modified_time
      @modified_time ||= File.stat(path).mtime
    end

    def mtime
      modified_time.to_i
    end

    def modified?
      @@mtimes[path] != mtime
    end

    def write?
      true
    end

    def write(dest)
      dest_path = destination(dest)

      return false if File.exist?(dest_path) and !modified?
      @@mtimes[path] = mtime

      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.rm(dest_path) if File.exist?(dest_path)
      FileUtils.cp(path, dest_path)
      File.utime(@@mtimes[path], @@mtimes[path], dest_path)

      true
    end

    def self.reset_cache
      @@mtimes = Hash.new
      nil
    end

    def to_liquid
      {
        "extname"       => extname,
        "modified_time" => modified_time,
        "path"          => File.join("", relative_path)
      }
    end
  end
end
