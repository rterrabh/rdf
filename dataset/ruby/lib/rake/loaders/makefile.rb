module Rake

  class MakefileLoader
    include Rake::DSL

    SPACE_MARK = "\0"

    def load(fn)
      lines = File.read fn
      lines.gsub!(/\\ /, SPACE_MARK)
      lines.gsub!(/#[^\n]*\n/m, "")
      lines.gsub!(/\\\n/, ' ')
      lines.each_line do |line|
        process_line(line)
      end
    end

    private

    def process_line(line)
      file_tasks, args = line.split(':', 2)
      return if args.nil?
      dependents = args.split.map { |d| respace(d) }
      file_tasks.scan(/\S+/) do |file_task|
        file_task = respace(file_task)
        file file_task => dependents
      end
    end

    def respace(str)
      str.tr SPACE_MARK, ' '
    end
  end

  Rake.application.add_loader('mf', MakefileLoader.new)
end
