module Jekyll
  class Regenerator
    attr_reader :site, :metadata, :cache

    def initialize(site)
      @site = site

      read_metadata

      clear_cache
    end

    def regenerate?(document)
      case document
      when Post, Page
        document.asset_file? || document.data['regenerate'] || 
          source_modified_or_dest_missing?(
            site.in_source_dir(document.relative_path), document.destination(@site.dest)
          )
      when Document
        !document.write? || document.data['regenerate'] ||
          source_modified_or_dest_missing?(
            document.path, document.destination(@site.dest)
          )
      else
        source_path = document.respond_to?(:path)        ? document.path                    : nil
        dest_path   = document.respond_to?(:destination) ? document.destination(@site.dest) : nil
        source_modified_or_dest_missing?(source_path, dest_path)
      end
    end

    def add(path)
      return true unless File.exist?(path)

      metadata[path] = {
        "mtime" => File.mtime(path),
        "deps" => []
      }
      cache[path] = true
    end

    def force(path)
      cache[path] = true
    end

    def clear
      @metadata = {}
      clear_cache
    end


    def clear_cache
      @cache = {}
    end


    def source_modified_or_dest_missing?(source_path, dest_path)
      modified?(source_path) || (dest_path and !File.exist?(dest_path))
    end

    def modified?(path)
      return true if disabled?

      return true if path.nil? 

      if cache.has_key? path
        return cache[path]
      end

      data = metadata[path]
      if data
        data["deps"].each do |dependency|
          if modified?(dependency)
            return cache[dependency] = cache[path] = true
          end
        end
        if File.exist?(path) && data["mtime"].eql?(File.mtime(path))
          return cache[path] = false
        else
          return add(path)
        end
      end

      return add(path)
    end

    def add_dependency(path, dependency)
      return if (metadata[path].nil? || @disabled)

      if !metadata[path]["deps"].include? dependency
        metadata[path]["deps"] << dependency
        add(dependency) unless metadata.include?(dependency)
      end
      regenerate? dependency
    end

    def write_metadata
      File.open(metadata_file, 'wb') do |f|
        f.write(Marshal.dump(metadata))
      end
    end

    def metadata_file
      site.in_source_dir('.jekyll-metadata')
    end

    def disabled?
      @disabled = site.full_rebuild? if @disabled.nil?
      @disabled
    end

    private

    def read_metadata
      @metadata = if !disabled? && File.file?(metadata_file)
        content = File.read(metadata_file)

        begin
          Marshal.load(content)
        rescue TypeError
          SafeYAML.load(content)
        rescue ArgumentError => e
          Jekyll.logger.warn("Failed to load #{metadata_file}: #{e}")
          {}
        end
      else
        {}
      end
    end
  end
end
