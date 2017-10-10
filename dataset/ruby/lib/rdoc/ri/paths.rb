require 'rdoc/ri'


module RDoc::RI::Paths

  require 'rbconfig'

  version = RbConfig::CONFIG['ruby_version']

  BASE    = if RbConfig::CONFIG.key? 'ridir' then
              File.join RbConfig::CONFIG['ridir'], version
            else
              File.join RbConfig::CONFIG['datadir'], 'ri', version
            end

  homedir = begin
              File.expand_path('~')
            rescue ArgumentError
            end

  homedir ||= ENV['HOME'] ||
              ENV['USERPROFILE'] || ENV['HOMEPATH'] # for 1.8 compatibility

  HOMEDIR = if homedir then
              File.join homedir, ".rdoc"
            end


  def self.each system = true, site = true, home = true, gems = :latest, *extra_dirs # :yields: directory, type
    return enum_for __method__, system, site, home, gems, *extra_dirs unless
      block_given?

    extra_dirs.each do |dir|
      yield dir, :extra
    end

    yield system_dir,  :system if system
    yield site_dir,    :site   if site
    yield home_dir,    :home   if home and HOMEDIR

    gemdirs(gems).each do |dir|
      yield dir, :gem
    end if gems

    nil
  end


  def self.gem_dir name, version
    req = Gem::Requirement.new "= #{version}"

    spec = Gem::Specification.find_by_name name, req

    File.join spec.doc_dir, 'ri'
  end


  def self.gemdirs filter = :latest
    require 'rubygems' unless defined?(Gem)

    ri_paths = {}

    all = Gem::Specification.map do |spec|
      [File.join(spec.doc_dir, 'ri'), spec.name, spec.version]
    end

    if filter == :all then
      gemdirs = []

      all.group_by do |_, name, _|
        name
      end.sort_by do |group, _|
        group
      end.map do |group, items|
        items.sort_by do |_, _, version|
          version
        end.reverse_each do |dir,|
          gemdirs << dir
        end
      end

      return gemdirs
    end

    all.each do |dir, name, ver|
      next unless File.exist? dir

      if ri_paths[name].nil? or ver > ri_paths[name].first then
        ri_paths[name] = [ver, name, dir]
      end
    end

    ri_paths.sort_by { |_, (_, name, _)| name }.map { |k, v| v.last }
  rescue LoadError
    []
  end


  def self.home_dir
    HOMEDIR
  end


  def self.path(system = true, site = true, home = true, gems = :latest, *extra_dirs)
    path = raw_path system, site, home, gems, *extra_dirs

    path.select { |directory| File.directory? directory }
  end


  def self.raw_path(system, site, home, gems, *extra_dirs)
    path = []

    each(system, site, home, gems, *extra_dirs) do |dir, type|
      path << dir
    end

    path.compact
  end


  def self.site_dir
    File.join BASE, 'site'
  end


  def self.system_dir
    File.join BASE, 'system'
  end

end

