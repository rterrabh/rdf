class SourceAnnotationExtractor
  class Annotation < Struct.new(:line, :tag, :text)
    def self.directories
      @@directories ||= %w(app config db lib test) + (ENV['SOURCE_ANNOTATION_DIRECTORIES'] || '').split(',')
    end

    def self.extensions
      @@extensions ||= {}
    end

    def self.register_extensions(*exts, &block)
      extensions[/\.(#{exts.join("|")})$/] = block
    end

    register_extensions("builder", "rb", "rake", "yml", "yaml", "ruby") { |tag| /#\s*(#{tag}):?\s*(.*)$/ }
    register_extensions("css", "js") { |tag| /\/\/\s*(#{tag}):?\s*(.*)$/ }
    register_extensions("erb") { |tag| /<%\s*#\s*(#{tag}):?\s*(.*?)\s*%>/ }

    def to_s(options={})
      s = "[#{line.to_s.rjust(options[:indent])}] "
      s << "[#{tag}] " if options[:tag]
      s << text
    end
  end

  def self.enumerate(tag, options={})
    extractor = new(tag)
    dirs = options.delete(:dirs) || Annotation.directories
    extractor.display(extractor.find(dirs), options)
  end

  attr_reader :tag

  def initialize(tag)
    @tag = tag
  end

  def find(dirs)
    dirs.inject({}) { |h, dir| h.update(find_in(dir)) }
  end

  def find_in(dir)
    results = {}

    Dir.glob("#{dir}/*") do |item|
      next if File.basename(item)[0] == ?.

      if File.directory?(item)
        results.update(find_in(item))
      else
        extension = Annotation.extensions.detect do |regexp, _block|
          regexp.match(item)
        end

        if extension
          pattern = extension.last.call(tag)
          results.update(extract_annotations_from(item, pattern)) if pattern
        end
      end
    end

    results
  end

  def extract_annotations_from(file, pattern)
    lineno = 0
    result = File.readlines(file).inject([]) do |list, line|
      lineno += 1
      next list unless line =~ pattern
      list << Annotation.new(lineno, $1, $2)
    end
    result.empty? ? {} : { file => result }
  end

  def display(results, options={})
    options[:indent] = results.flat_map { |f, a| a.map(&:line) }.max.to_s.size
    results.keys.sort.each do |file|
      puts "#{file}:"
      results[file].each do |note|
        puts "  * #{note.to_s(options)}"
      end
      puts
    end
  end
end
