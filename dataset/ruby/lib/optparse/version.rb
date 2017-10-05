# OptionParser internal utility

class << OptionParser
  def show_version(*pkgs)
    progname = ARGV.options.program_name
    result = false
    show = proc do |klass, cname, version|
      str = "#{progname}"
      unless klass == ::Object and cname == :VERSION
        version = version.join(".") if Array === version
        str << ": #{klass}" unless klass == Object
        str << " version #{version}"
      end
      [:Release, :RELEASE].find do |rel|
        if klass.const_defined?(rel)
          #nodyna <ID:const_get-31> <CG MODERATE (array)>
          str << " (#{klass.const_get(rel)})"
        end
      end
      puts str
      result = true
    end
    if pkgs.size == 1 and pkgs[0] == "all"
      self.search_const(::Object, /\AV(?:ERSION|ersion)\z/) do |klass, cname, version|
        unless cname[1] == ?e and klass.const_defined?(:Version)
          show.call(klass, cname.intern, version)
        end
      end
    else
      pkgs.each do |pkg|
        begin
          #nodyna <ID:const_get-32> <CG COMPLEX (array)>
          pkg = pkg.split(/::|\//).inject(::Object) {|m, c| m.const_get(c)}
          v = case
              when pkg.const_defined?(:Version)
                #nodyna <ID:const_get-33> <CG TRIVIAL (static values)>
                pkg.const_get(n = :Version)
              when pkg.const_defined?(:VERSION)
                #nodyna <ID:const_get-34> <CG TRIVIAL (static values)>
                pkg.const_get(n = :VERSION)
              else
                n = nil
                "unknown"
              end
          show.call(pkg, n, v)
        rescue NameError
        end
      end
    end
    result
  end

  def each_const(path, base = ::Object)
    path.split(/::|\//).inject(base) do |klass, name|
      raise NameError, path unless Module === klass
      klass.constants.grep(/#{name}/i) do |c|
        klass.const_defined?(c) or next
        #nodyna <ID:const_get-35> <CG COMPLEX (array)>
        klass.const_get(c)
      end
    end
  end

  def search_const(klass, name)
    klasses = [klass]
    while klass = klasses.shift
      klass.constants.each do |cname|
        klass.const_defined?(cname) or next
        #nodyna <ID:const_get-36> <CG COMPLEX (array)>
        const = klass.const_get(cname)
        yield klass, cname, const if name === cname
        klasses << const if Module === const and const != ::Object
      end
    end
  end
end
