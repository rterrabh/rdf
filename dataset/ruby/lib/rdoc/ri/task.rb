require 'rubygems'
begin
  gem 'rdoc'
rescue Gem::LoadError
end unless defined?(RDoc)

require 'rdoc/task'


class RDoc::RI::Task < RDoc::Task

  DEFAULT_NAMES = { # :nodoc:
    :clobber_rdoc => :clobber_ri,
    :rdoc         => :ri,
    :rerdoc       => :reri,
  }


  def initialize name = DEFAULT_NAMES # :yield: self
    super
  end

  def clobber_task_description # :nodoc:
    "Remove RI data files"
  end


  def defaults
    super

    @rdoc_dir = '.rdoc'
  end

  def rdoc_task_description # :nodoc:
    'Build RI data files'
  end

  def rerdoc_task_description # :nodoc:
    'Rebuild RI data files'
  end
end
