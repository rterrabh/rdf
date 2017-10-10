
require 'rake'

task :phony

Rake::Task[:phony].tap do |task|
  def task.timestamp # :nodoc:
    Time.at 0
  end
end
