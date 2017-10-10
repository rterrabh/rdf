module Pod
  class Sandbox
    class PathList
      attr_accessor :root

      def initialize(root)
        @root = root
        @glob_cache = {}
      end

      def files
        read_file_system unless @files
        @files
      end

      def dirs
        read_file_system unless @dirs
        @dirs
      end

      def read_file_system
        unless root.exist?
          raise Informative, "Attempt to read non existent folder `#{root}`."
        end
        root_length  = root.to_s.length + 1
        escaped_root = escape_path_for_glob(root)
        paths  = Dir.glob(escaped_root + '**/*', File::FNM_DOTMATCH)
        absolute_dirs  = paths.select { |path| File.directory?(path) }
        relative_dirs  = absolute_dirs.map  { |p| p[root_length..-1] }
        absolute_paths = paths.reject { |p| p == "#{root}/." || p == "#{root}/.." }
        relative_paths = absolute_paths.map { |p| p[root_length..-1] }
        @files = relative_paths - relative_dirs
        @dirs  = relative_dirs.map { |d| d.gsub(/\/\.\.?$/, '') }.reject { |d| d == '.' || d == '..' } .uniq
        @glob_cache = {}
      end


      public


      def glob(patterns, options = {})
        relative_glob(patterns, options).map { |p| root + p }
      end

      def relative_glob(patterns, options = {})
        return [] if patterns.empty?

        cache_key = options.merge(:patterns => patterns)
        cached_value = @glob_cache[cache_key]
        return cached_value if cached_value

        dir_pattern = options[:dir_pattern]
        exclude_patterns = options[:exclude_patterns]
        include_dirs = options[:include_dirs]

        if include_dirs
          full_list = files + dirs
        else
          full_list = files
        end

        list = Array(patterns).map do |pattern|
          if directory?(pattern) && dir_pattern
            pattern += '/' unless pattern.end_with?('/')
            pattern += dir_pattern
          end
          expanded_patterns = dir_glob_equivalent_patterns(pattern)
          full_list.select do |path|
            expanded_patterns.any? do |p|
              File.fnmatch(p, path, File::FNM_CASEFOLD | File::FNM_PATHNAME)
            end
          end
        end.flatten

        list = list.map { |path| Pathname.new(path) }
        if exclude_patterns
          exclude_options = { :dir_pattern => '**/*', :include_dirs => include_dirs }
          list -= relative_glob(exclude_patterns, exclude_options)
        end
        @glob_cache[cache_key] = list
      end


      private


      def directory?(sub_path)
        sub_path = sub_path.to_s.downcase.sub(/\/$/, '')
        dirs.any? { |dir| dir.downcase == sub_path }
      end

      def dir_glob_equivalent_patterns(pattern)
        pattern = pattern.gsub('/**/', '{/**/,/}')
        values_by_set = {}
        pattern.scan(/\{[^}]*\}/) do |set|
          values = set.gsub(/[{}]/, '').split(',')
          values_by_set[set] = values
        end

        if values_by_set.empty?
          [pattern]
        else
          patterns = [pattern]
          values_by_set.each do |set, values|
            patterns = patterns.map do |old_pattern|
              values.map do |value|
                old_pattern.gsub(set, value)
              end
            end.flatten
          end
          patterns
        end
      end

      def escape_path_for_glob(path)
        result = path.to_s
        characters_to_escape = ['[', ']', '{', '}', '?', '*']
        characters_to_escape.each do |character|
          result.gsub!(character, "\\#{character}")
        end
        Pathname.new(result)
      end

    end
  end
end
