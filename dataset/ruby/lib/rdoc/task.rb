
require 'rubygems'
begin
  gem 'rdoc'
rescue Gem::LoadError
end unless defined?(RDoc)

begin
  gem 'rake'
rescue Gem::LoadError
end unless defined?(Rake)

require 'rdoc'
require 'rake'
require 'rake/tasklib'


class RDoc::Task < Rake::TaskLib


  attr_accessor :name


  attr_accessor :markup


  attr_accessor :rdoc_dir


  attr_accessor :title


  attr_accessor :main


  attr_accessor :template


  attr_accessor :generator


  attr_accessor :rdoc_files


  attr_accessor :options


  attr_accessor :external


  def initialize name = :rdoc # :yield: self
    defaults

    check_names name

    @name = name

    yield self if block_given?

    define
  end


  def check_names names
    return unless Hash === names

    invalid_options =
      names.keys.map { |k| k.to_sym } - [:rdoc, :clobber_rdoc, :rerdoc]

    unless invalid_options.empty? then
      raise ArgumentError, "invalid options: #{invalid_options.join ', '}"
    end
  end


  def clobber_task_description
    "Remove RDoc HTML files"
  end


  def defaults
    @name = :rdoc
    @rdoc_files = Rake::FileList.new
    @rdoc_dir = 'html'
    @main = nil
    @title = nil
    @template = nil
    @generator = nil
    @options = []
  end


  def inline_source # :nodoc:
    warn "RDoc::Task#inline_source is deprecated"
    true
  end


  def inline_source=(value) # :nodoc:
    warn "RDoc::Task#inline_source is deprecated"
  end


  def define
    desc rdoc_task_description
    task rdoc_task_name

    desc rerdoc_task_description
    task rerdoc_task_name => [clobber_task_name, rdoc_task_name]

    desc clobber_task_description
    task clobber_task_name do
      rm_r @rdoc_dir rescue nil
    end

    task :clobber => [clobber_task_name]

    directory @rdoc_dir

    rdoc_target_deps = [
      @rdoc_files,
      Rake.application.rakefile
    ].flatten.compact

    task rdoc_task_name => [rdoc_target]
    file rdoc_target => rdoc_target_deps do
      @before_running_rdoc.call if @before_running_rdoc
      args = option_list + @rdoc_files

      $stderr.puts "rdoc #{args.join ' '}" if Rake.application.options.trace
      RDoc::RDoc.new.document args
    end

    self
  end


  def option_list
    result = @options.dup
    result << "-o"       << @rdoc_dir
    result << "--main"   << main      if main
    result << "--markup" << markup    if markup
    result << "--title"  << title     if title
    result << "-T"       << template  if template
    result << '-f'       << generator if generator
    result
  end


  def before_running_rdoc(&block)
    @before_running_rdoc = block
  end


  def rdoc_task_description
    'Build RDoc HTML files'
  end


  def rerdoc_task_description
    "Rebuild RDoc HTML files"
  end

  private

  def rdoc_target
    "#{rdoc_dir}/created.rid"
  end

  def rdoc_task_name
    case name
    when Hash then (name[:rdoc] || "rdoc").to_s
    else           name.to_s
    end
  end

  def clobber_task_name
    case name
    when Hash then (name[:clobber_rdoc] || "clobber_rdoc").to_s
    else           "clobber_#{name}"
    end
  end

  def rerdoc_task_name
    case name
    when Hash then (name[:rerdoc] || "rerdoc").to_s
    else           "re#{name}"
    end
  end

end

module Rake


  RDocTask = RDoc::Task

end

