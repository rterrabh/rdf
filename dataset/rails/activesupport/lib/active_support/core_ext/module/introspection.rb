require 'active_support/inflector'

class Module
  def parent_name
    if defined? @parent_name
      @parent_name
    else
      @parent_name = name =~ /::[^:]+\Z/ ? $`.freeze : nil
    end
  end

  def parent
    parent_name ? ActiveSupport::Inflector.constantize(parent_name) : Object
  end

  def parents
    parents = []
    if parent_name
      parts = parent_name.split('::')
      until parts.empty?
        parents << ActiveSupport::Inflector.constantize(parts * '::')
        parts.pop
      end
    end
    parents << Object unless parents.include? Object
    parents
  end

  def local_constants #:nodoc:
    constants(false)
  end
end
