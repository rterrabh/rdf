module Jekyll
  module Utils extend self
    autoload :Platforms, 'jekyll/utils/platforms'

    SLUGIFY_MODES = %w{raw default pretty}
    SLUGIFY_RAW_REGEXP = Regexp.new('\\s+').freeze
    SLUGIFY_DEFAULT_REGEXP = Regexp.new('[^[:alnum:]]+').freeze
    SLUGIFY_PRETTY_REGEXP = Regexp.new("[^[:alnum:]._~!$&'()+,;=@]+").freeze

    def deep_merge_hashes(master_hash, other_hash)
      target = master_hash.dup

      other_hash.each_key do |key|
        if other_hash[key].is_a? Hash and target[key].is_a? Hash
          target[key] = Utils.deep_merge_hashes(target[key], other_hash[key])
          next
        end

        target[key] = other_hash[key]
      end

      target
    end

    def pluralized_array_from_hash(hash, singular_key, plural_key)
      [].tap do |array|
        array << (value_from_singular_key(hash, singular_key) || value_from_plural_key(hash, plural_key))
      end.flatten.compact
    end

    def value_from_singular_key(hash, key)
      hash[key] if (hash.key?(key) || (hash.default_proc && hash[key]))
    end

    def value_from_plural_key(hash, key)
      if hash.key?(key) || (hash.default_proc && hash[key])
        val = hash[key]
        case val
        when String
          val.split
        when Array
          val.compact
        end
      end
    end

    def transform_keys(hash)
      result = {}
      hash.each_key do |key|
        result[yield(key)] = hash[key]
      end
      result
    end

    def symbolize_hash_keys(hash)
      transform_keys(hash) { |key| key.to_sym rescue key }
    end

    def stringify_hash_keys(hash)
      transform_keys(hash) { |key| key.to_s rescue key }
    end

    def parse_date(input, msg = "Input could not be parsed.")
      Time.parse(input).localtime
    rescue ArgumentError
      raise Errors::FatalException.new("Invalid date '#{input}': " + msg)
    end

    def has_yaml_header?(file)
      !!(File.open(file, 'rb') { |f| f.read(5) } =~ /\A---\r?\n/)
    end

    def slugify(string, mode=nil)
      mode ||= 'default'
      return nil if string.nil?
      return string.downcase unless SLUGIFY_MODES.include?(mode)

      re = case mode
      when 'raw'
        SLUGIFY_RAW_REGEXP
      when 'default'
        SLUGIFY_DEFAULT_REGEXP
      when 'pretty'
        SLUGIFY_PRETTY_REGEXP
      end

      string.
        gsub(re, '-').
        gsub(/^\-|\-$/i, '').
        downcase
    end

    def add_permalink_suffix(template, permalink_style)
      case permalink_style
      when :pretty
        template << "/"
      when :date, :ordinal, :none
        template << ":output_ext"
      else
        template << "/" if permalink_style.to_s.end_with?("/")
        template << ":output_ext" if permalink_style.to_s.end_with?(":output_ext")
      end
      template
    end

  end
end
