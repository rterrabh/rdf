require 'rake/file_task'
require 'rake/early_time'

module Rake

  class FileCreationTask < FileTask
    def needed?
      ! File.exist?(name)
    end

    def timestamp
      Rake::EARLY
    end
  end

end
