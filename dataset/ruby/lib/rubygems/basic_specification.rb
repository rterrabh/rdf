
class Gem::BasicSpecification


  attr_writer :base_dir # :nodoc:


  attr_writer :extension_dir # :nodoc:


  attr_writer :ignored # :nodoc:


  attr_reader :loaded_from


  attr_writer :full_gem_path # :nodoc:

  def self.default_specifications_dir
    File.join(Gem.default_dir, "specifications", "default")
  end


  def activated?
    raise NotImplementedError
  end


  def base_dir
    return Gem.dir unless loaded_from
    @base_dir ||= if default_gem? then
                    File.dirname File.dirname File.dirname loaded_from
                  else
                    File.dirname File.dirname loaded_from
                  end
  end


  def contains_requirable_file? file
    @contains_requirable_file ||= {}
    @contains_requirable_file[file] ||=
    begin
      if instance_variable_defined?(:@ignored) or
         instance_variable_defined?('@ignored') then
        return false
      elsif missing_extensions? then
        @ignored = true

        warn "Ignoring #{full_name} because its extensions are not built.  " +
             "Try: gem pristine #{name} --version #{version}"
        return false
      end

      suffixes = Gem.suffixes

      full_require_paths.any? do |dir|
        base = "#{dir}/#{file}"
        suffixes.any? { |suf| File.file? "#{base}#{suf}" }
      end
    end ? :yes : :no
    @contains_requirable_file[file] == :yes
  end

  def default_gem?
    loaded_from &&
      File.dirname(loaded_from) == self.class.default_specifications_dir
  end


  def extension_dir
    @extension_dir ||= File.expand_path File.join(extensions_dir, full_name)
  end


  def extensions_dir
    @extensions_dir ||= Gem.default_ext_dir_for(base_dir) ||
      File.join(base_dir, 'extensions', Gem::Platform.local.to_s,
                Gem.extension_api_version)
  end

  def find_full_gem_path # :nodoc:
    path = File.expand_path File.join(gems_dir, full_name)
    path.untaint
    path if File.directory? path
  end

  private :find_full_gem_path


  def full_gem_path
    @full_gem_path ||= find_full_gem_path
  end


  def full_name
    if platform == Gem::Platform::RUBY or platform.nil? then
      "#{name}-#{version}".untaint
    else
      "#{name}-#{version}-#{platform}".untaint
    end
  end


  def full_require_paths
    @full_require_paths ||=
    begin
      full_paths = raw_require_paths.map do |path|
        File.join full_gem_path, path
      end

      full_paths.unshift extension_dir unless @extensions.nil? || @extensions.empty?

      full_paths
    end
  end


  def to_fullpath path
    if activated? then
      @paths_map ||= {}
      @paths_map[path] ||=
      begin
        fullpath = nil
        suffixes = Gem.suffixes
        full_require_paths.find do |dir|
          suffixes.find do |suf|
            File.file?(fullpath = "#{dir}/#{path}#{suf}")
          end
        end ? fullpath : nil
      end
    else
      nil
    end
  end


  def gem_dir
    @gem_dir ||= File.expand_path File.join(gems_dir, full_name)
  end


  def gems_dir
    @gems_dir ||= File.join(loaded_from && base_dir || Gem.dir, "gems")
  end


  def loaded_from= path
    @loaded_from   = path && path.to_s

    @extension_dir = nil
    @extensions_dir = nil
    @full_gem_path         = nil
    @gem_dir               = nil
    @gems_dir              = nil
    @base_dir              = nil
  end


  def name
    raise NotImplementedError
  end


  def platform
    raise NotImplementedError
  end

  def raw_require_paths # :nodoc:
    Array(@require_paths)
  end


  def require_paths
    return raw_require_paths if @extensions.nil? || @extensions.empty?

    [extension_dir].concat raw_require_paths
  end


  def source_paths
    paths = raw_require_paths.dup

    if @extensions then
      ext_dirs = @extensions.map do |extension|
        extension.split(File::SEPARATOR, 2).first
      end.uniq

      paths.concat ext_dirs
    end

    paths.uniq
  end


  def to_spec
    raise NotImplementedError
  end


  def version
    raise NotImplementedError
  end

  def stubbed?
    raise NotImplementedError
  end

end

