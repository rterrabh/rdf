
require 'rbconfig'
require 'cgi'

module Pod
  module UserInterface
    module ErrorReport
      class << self
        def report(exception)
          <<-EOS



```
```


* What did you do?

* What did you expect to happen?

* What happened instead?



```
   CocoaPods : #{Pod::VERSION}
        Ruby : #{RUBY_DESCRIPTION}
    RubyGems : #{Gem::VERSION}
        Host : #{host_information}
       Xcode : #{xcode_information}
         Git : #{git_information}
Ruby lib dir : #{RbConfig::CONFIG['libdir']}
Repositories : #{repo_information.join("\n               ")}
```


```
```

```
```



https://github.com/CocoaPods/CocoaPods/issues/new

https://github.com/CocoaPods/CocoaPods/blob/master/CONTRIBUTING.md

Don't forget to anonymize any private data!

EOS
        end

        private

        def `(other)
          super
        rescue Errno::ENOENT => e
          "Unable to find an executable (#{e})"
        end

        def pathless_exception_message(message)
          message.gsub(/- \(.*\):/, '-')
        end

        def markdown_podfile
          return '' unless Config.instance.podfile_path && Config.instance.podfile_path.exist?
          <<-EOS


```ruby
```
EOS
        end

        def error_from_podfile(error)
          if error.message =~ /Podfile:(\d*)/
            "\nIt appears to have originated from your Podfile at line #{Regexp.last_match[1]}.\n"
          end
        end

        def remove_color(string)
          string.gsub(/\e\[(\d+)m/, '')
        end

        def issues_url(exception)
          message = remove_color(pathless_exception_message(exception.message))
          'https://github.com/CocoaPods/CocoaPods/search?q=' \
          "#{CGI.escape(message)}&type=Issues"
        end

        def host_information
          product, version, build = `sw_vers`.strip.split("\n").map { |line| line.split(':').last.strip }
          "#{product} #{version} (#{build})"
        end

        def xcode_information
          version, build = `xcodebuild -version`.strip.split("\n").map { |line| line.split(' ').last }
          "#{version} (#{build})"
        end

        def git_information
          `git --version`.strip.split("\n").first
        end

        def installed_plugins
          CLAide::Command::PluginManager.specifications.
            reduce({}) { |hash, s| hash.tap { |h| h[s.name] = s.version.to_s } }
        end

        def plugins_string
          plugins = installed_plugins
          max_name_length = plugins.keys.map(&:length).max
          plugins.map do |name, version|
            "#{name.ljust(max_name_length)} : #{version}"
          end.sort.join("\n")
        end

        def repo_information
          SourcesManager.all.map do |source|
            next unless source.type == 'file system'
            repo = source.repo
            Dir.chdir(repo) do
              url = `git config --get remote.origin.url 2>&1`.strip
              sha = `git rev-parse HEAD 2>&1`.strip
              "#{repo.basename} - #{url} @ #{sha}"
            end
          end
        end

        def original_command
          "#{$PROGRAM_NAME} #{ARGV.join(' ')}"
        end
      end
    end
  end
end