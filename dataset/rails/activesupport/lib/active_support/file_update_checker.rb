module ActiveSupport
  class FileUpdateChecker
    def initialize(files, dirs={}, &block)
      @files = files.freeze
      @glob  = compile_glob(dirs)
      @block = block

      @watched    = nil
      @updated_at = nil

      @last_watched   = watched
      @last_update_at = updated_at(@last_watched)
    end

    def updated?
      current_watched = watched
      if @last_watched.size != current_watched.size
        @watched = current_watched
        true
      else
        current_updated_at = updated_at(current_watched)
        if @last_update_at < current_updated_at
          @watched    = current_watched
          @updated_at = current_updated_at
          true
        else
          false
        end
      end
    end

    def execute
      @last_watched   = watched
      @last_update_at = updated_at(@last_watched)
      @block.call
    ensure
      @watched = nil
      @updated_at = nil
    end

    def execute_if_updated
      if updated?
        execute
        true
      else
        false
      end
    end

    private

    def watched
      @watched || begin
        all = @files.select { |f| File.exist?(f) }
        all.concat(Dir[@glob]) if @glob
        all
      end
    end

    def updated_at(paths)
      @updated_at || max_mtime(paths) || Time.at(0)
    end

    def max_mtime(paths)
      time_now = Time.now
      paths.map {|path| File.mtime(path)}.reject {|mtime| time_now < mtime}.max
    end

    def compile_glob(hash)
      hash.freeze # Freeze so changes aren't accidentally pushed
      return if hash.empty?

      globs = hash.map do |key, value|
        "#{escape(key)}/**/*#{compile_ext(value)}"
      end
      "{#{globs.join(",")}}"
    end

    def escape(key)
      key.gsub(',','\,')
    end

    def compile_ext(array)
      array = Array(array)
      return if array.empty?
      ".{#{array.join(",")}}"
    end
  end
end
