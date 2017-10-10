module Jekyll
  class DataReader
    attr_reader :site, :content
    def initialize(site)
      @site = site
      @content = {}
    end

    def read(dir)
      base = site.in_source_dir(dir)
      read_data_to(base, @content)
      @content
    end

    def read_data_to(dir, data)
      return unless File.directory?(dir) && (!site.safe || !File.symlink?(dir))

      entries = Dir.chdir(dir) do
        Dir['*.{yaml,yml,json,csv}'] + Dir['*'].select { |fn| File.directory?(fn) }
      end

      entries.each do |entry|
        path = @site.in_source_dir(dir, entry)
        next if File.symlink?(path) && site.safe

        key = sanitize_filename(File.basename(entry, '.*'))
        if File.directory?(path)
          read_data_to(path, data[key] = {})
        else
          data[key] = read_data_file(path)
        end
      end
    end

    def read_data_file(path)
      case File.extname(path).downcase
        when '.csv'
          CSV.read(path, {
                           :headers => true,
                           :encoding => site.config['encoding']
                       }).map(&:to_hash)
        else
          SafeYAML.load_file(path)
      end
    end

    def sanitize_filename(name)
      name.gsub!(/[^\w\s-]+/, '')
      name.gsub!(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
      name.gsub(/\s+/, '_')
    end
  end
end
