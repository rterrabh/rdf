require 'cocoapods/user_interface/error_report'

module Pod
  module UserInterface
    require 'colored'

    @title_colors      =  %w(    yellow green    )
    @title_level       =  0
    @indentation_level =  2
    @treat_titles_as_messages = false
    @warnings = []

    class << self
      include Config::Mixin

      attr_accessor :indentation_level
      attr_accessor :title_level
      attr_accessor :warnings

      attr_accessor :disable_wrap
      alias_method :disable_wrap?, :disable_wrap

      def section(title, verbose_prefix = '', relative_indentation = 0)
        if config.verbose?
          title(title, verbose_prefix, relative_indentation)
        elsif title_level < 1
          puts title
        end

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end

      def titled_section(title, options = {})
        relative_indentation = options[:relative_indentation] || 0
        verbose_prefix = options[:verbose_prefix] || ''
        if config.verbose?
          title(title, verbose_prefix, relative_indentation)
        else
          puts title
        end

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end

      def title(title, verbose_prefix = '', relative_indentation = 2)
        if @treat_titles_as_messages
          message(title, verbose_prefix)
        else
          title = verbose_prefix + title if config.verbose?
          title = "\n#{title}" if @title_level < 2
          if (color = @title_colors[@title_level])
            #nodyna <send-2697> <not yet classified>
            title = title.send(color)
          end
          puts "#{title}"
        end

        self.indentation_level += relative_indentation
        self.title_level += 1
        yield if block_given?
        self.indentation_level -= relative_indentation
        self.title_level -= 1
      end


      def message(message, verbose_prefix = '', relative_indentation = 2)
        message = verbose_prefix + message if config.verbose?
        puts_indented message if config.verbose?

        self.indentation_level += relative_indentation
        yield if block_given?
        self.indentation_level -= relative_indentation
      end

      def info(message)
        indentation = config.verbose? ? self.indentation_level : 0
        indented = wrap_string(message, indentation)
        puts(indented)

        self.indentation_level += 2
        @treat_titles_as_messages = true
        yield if block_given?
        @treat_titles_as_messages = false
        self.indentation_level -= 2
      end

      def notice(message)
        puts("\n[!] #{message}".green)
      end

      def path(pathname)
        if pathname
          from_path = config.podfile_path.dirname if config.podfile_path
          from_path ||= Pathname.pwd
          path = Pathname(pathname).relative_path_from(from_path)
          "`#{path}`"
        else
          ''
        end
      end

      def pod(set, mode = :normal)
        if mode == :name_and_version
          puts_indented "#{set.name} #{set.versions.first.version}"
        else
          pod = Specification::Set::Presenter.new(set)
          title = "\n-> #{pod.name} (#{pod.version})"
          if pod.spec.deprecated?
            title += " #{pod.deprecation_description}"
            colored_title = title.red
          else
            colored_title = title.green
          end

          title(colored_title, '', 1) do
            puts_indented pod.summary if pod.summary
            puts_indented "pod '#{pod.name}', '~> #{pod.version}'"
            labeled('Homepage', pod.homepage)
            labeled('Source',   pod.source_url)
            labeled('Versions', pod.versions_by_source)
            if mode == :stats
              labeled('Authors',  pod.authors) if pod.authors =~ /,/
              labeled('Author',   pod.authors) if pod.authors !~ /,/
              labeled('License',  pod.license)
              labeled('Platform', pod.platform)
              labeled('Stars',    pod.github_stargazers)
              labeled('Forks',    pod.github_forks)
            end
            labeled('Subspecs', pod.subspecs)
          end
        end
      end

      def labeled(label, value, justification = 12)
        if value
          title = "- #{label}:"
          if value.is_a?(Array)
            lines = [wrap_string(title, self.indentation_level)]
            value.each do |v|
              lines << wrap_string("- #{v}", self.indentation_level + 2)
            end
            puts lines.join("\n")
          else
            puts wrap_string(title.ljust(justification) + "#{value}", self.indentation_level)
          end
        end
      end

      def puts_indented(message = '')
        indented = wrap_string(message, self.indentation_level)
        puts(indented)
      end

      def print_warnings
        STDOUT.flush
        warnings.each do |warning|
          next if warning[:verbose_only] && !config.verbose?
          STDERR.puts("\n[!] #{warning[:message]}".yellow)
          warning[:actions].each do |action|
            string = "- #{action}"
            string = wrap_string(string, 4)
            puts(string)
          end
        end
      end

      def choose_from_array(array, message)
        array.each_with_index do |item, index|
          UI.puts "#{ index + 1 }: #{ item }"
        end

        UI.puts message

        index = UI.gets.chomp.to_i - 1
        if index < 0 || index > array.count - 1
          raise Informative, "#{ index + 1 } is invalid [1-#{ array.count }]"
        else
          index
        end
      end

      public


      def puts(message = '')
        STDOUT.puts(message) unless config.silent?
      end

      def print(message)
        STDOUT.print(message) unless config.silent?
      end

      def gets
        $stdin.gets
      end

      def warn(message, actions = [], verbose_only = false)
        warnings << { :message => message, :actions => actions, :verbose_only => verbose_only }
      end

      private


      def wrap_string(string, indent = 0)
        if disable_wrap
          (' ' * indent) + string
        else
          first_space = ' ' * indent
          indented = CLAide::Command::Banner::TextWrapper.wrap_with_indent(string, indent, 9999)
          first_space + indented
        end
      end
    end
  end
  UI = UserInterface


  module CoreUI
    class << self
      def puts(message)
        UI.puts message
      end

      def warn(message)
        UI.warn message
      end
    end
  end
end


module Xcodeproj
  module UserInterface
    def self.puts(message)
      ::Pod::UI.puts message
    end

    def self.warn(message)
      ::Pod::UI.warn message
    end
  end
end
