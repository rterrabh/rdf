require 'rake/application'

module Rake

  class << self
    def application
      @application ||= Rake::Application.new
    end

    def application=(app)
      @application = app
    end

    def suggested_thread_count # :nodoc:
      @cpu_count ||= Rake::CpuCounter.count
      @cpu_count + 4
    end

    def original_dir
      application.original_dir
    end

    def load_rakefile(path)
      load(path)
    end

    def add_rakelib(*files)
      application.options.rakelib ||= []
      application.options.rakelib.concat(files)
    end
  end

end
