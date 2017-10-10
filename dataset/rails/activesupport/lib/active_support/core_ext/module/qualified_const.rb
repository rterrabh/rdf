require 'active_support/core_ext/string/inflections'

module QualifiedConstUtils
  def self.raise_if_absolute(path)
    raise NameError.new("wrong constant name #$&") if path =~ /\A::[^:]+/
  end

  def self.names(path)
    path.split('::')
  end
end

class Module
  def qualified_const_defined?(path, search_parents=true)
    QualifiedConstUtils.raise_if_absolute(path)

    QualifiedConstUtils.names(path).inject(self) do |mod, name|
      return unless mod.const_defined?(name, search_parents)
      #nodyna <const_get-1043> <CG COMPLEX (array)>
      mod.const_get(name)
    end
    return true
  end

  def qualified_const_get(path)
    QualifiedConstUtils.raise_if_absolute(path)

    QualifiedConstUtils.names(path).inject(self) do |mod, name|
      #nodyna <const_get-1044> <CG COMPLEX (array)>
      mod.const_get(name)
    end
  end

  def qualified_const_set(path, value)
    QualifiedConstUtils.raise_if_absolute(path)

    const_name = path.demodulize
    mod_name = path.deconstantize
    mod = mod_name.empty? ? self : qualified_const_get(mod_name)
    #nodyna <const_set-1045> <CS COMPLEX (change-prone variable)>
    mod.const_set(const_name, value)
  end
end
