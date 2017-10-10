module Jekyll
  class Collection
    attr_reader :site, :label, :metadata

    def initialize(site, label)
      @site     = site
      @label    = sanitize_label(label)
      @metadata = extract_metadata
    end

    def docs
      @docs ||= []
    end

    def files
      @files ||= []
    end

    def read
      filtered_entries.each do |file_path|
        full_path = collection_dir(file_path)
        next if File.directory?(full_path)
        if Utils.has_yaml_header? full_path
          doc = Jekyll::Document.new(full_path, { site: site, collection: self })
          doc.read
          docs << doc if site.publisher.publish?(doc)
        else
          relative_dir = Jekyll.sanitized_path(relative_directory, File.dirname(file_path)).chomp("/.")
          files << StaticFile.new(site, site.source, relative_dir, File.basename(full_path), self)
        end
      end
      docs.sort!
    end

    def entries
      return Array.new unless exists?
      @entries ||=
        Dir.glob(collection_dir("**", "*.*")).map do |entry|
          entry["#{collection_dir}/"] = ''; entry
        end
    end

    def filtered_entries
      return Array.new unless exists?
      @filtered_entries ||=
        Dir.chdir(directory) do
          entry_filter.filter(entries).reject do |f|
            path = collection_dir(f)
            File.directory?(path) || (File.symlink?(f) && site.safe)
          end
        end
    end

    def relative_directory
      @relative_directory ||= "_#{label}"
    end

    def directory
      @directory ||= site.in_source_dir(relative_directory)
    end

    def collection_dir(*files)
      return directory if files.empty?
      site.in_source_dir(relative_directory, *files)
    end

    def exists?
      File.directory?(directory) && !(File.symlink?(directory) && site.safe)
    end

    def entry_filter
      @entry_filter ||= Jekyll::EntryFilter.new(site, relative_directory)
    end

    def inspect
      "#<Jekyll::Collection @label=#{label} docs=#{docs}>"
    end

    def sanitize_label(label)
      label.gsub(/[^a-z0-9_\-\.]/i, '')
    end

    def to_liquid
      metadata.merge({
        "label"     => label,
        "docs"      => docs,
        "files"     => files,
        "directory" => directory,
        "output"    => write?,
        "relative_directory" => relative_directory
      })
    end

    def write?
      !!metadata['output']
    end

    def url_template
      metadata.fetch('permalink') do
          Utils.add_permalink_suffix("/:collection/:path", site.permalink_style)
      end
    end

    def extract_metadata
      if site.config['collections'].is_a?(Hash)
        site.config['collections'][label] || Hash.new
      else
        {}
      end
    end
  end
end
