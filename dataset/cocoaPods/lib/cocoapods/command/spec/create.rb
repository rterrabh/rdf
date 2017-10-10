
module Pod
  class Command
    class Spec < Command
      class Create < Spec
        self.summary = 'Create spec file stub.'

        self.description = <<-DESC
          Creates a PodSpec, in the current working dir, called `NAME.podspec'.
          If a GitHub url is passed the spec is prepopulated.
        DESC

        self.arguments = [
          CLAide::Argument.new(%w(NAME https://github.com/USER/REPO), false),
        ]

        def initialize(argv)
          @name_or_url, @url = argv.shift_argument, argv.shift_argument
          super
        end

        def validate!
          super
          help! 'A pod name or repo URL is required.' unless @name_or_url
        end

        def run
          if repo_id_match = (@url || @name_or_url).match(%r{github.com/([^/\.]*\/[^/\.]*)\.*})
            repo_id = repo_id_match[1]
            data = github_data_for_template(repo_id)
            data[:name] = @name_or_url if @url
            UI.puts semantic_versioning_notice(repo_id, data[:name]) if data[:version] == '0.0.1'
          else
            data = default_data_for_template(@name_or_url)
          end

          spec = spec_template(data)
          (Pathname.pwd + "#{data[:name]}.podspec").open('w') { |f| f << spec }
          UI.puts "\nSpecification created at #{data[:name]}.podspec".green
        end

        private



        def default_data_for_template(name)
          data = {}
          data[:name]          = name
          data[:version]       = '0.0.1'
          data[:summary]       = "A short description of #{name}."
          data[:homepage]      = "http://EXAMPLE/#{name}"
          data[:author_name]   = `git config --get user.name`.strip
          data[:author_email]  = `git config --get user.email`.strip
          data[:source_url]    = "http://EXAMPLE/#{name}.git"
          data[:ref_type]      = ':tag'
          data[:ref]           = '0.0.1'
          data
        end

        def github_data_for_template(repo_id)
          repo = GitHub.repo(repo_id)
          raise Informative, "Unable to fetch data for `#{repo_id}`" unless repo
          user = GitHub.user(repo['owner']['login'])
          raise Informative, "Unable to fetch data for `#{repo['owner']['login']}`" unless user
          data = {}

          data[:name]          = repo['name']
          data[:summary]       = (repo['description'] || '').gsub(/["]/, '\"')
          data[:homepage]      = (repo['homepage'] && !repo['homepage'].empty?) ? repo['homepage'] : repo['html_url']
          data[:author_name]   = user['name']  || user['login']
          data[:author_email]  = user['email'] || 'email@address.com'
          data[:source_url]    = repo['clone_url']

          data.merge suggested_ref_and_version(repo)
        end

        def suggested_ref_and_version(repo)
          tags = GitHub.tags(repo['html_url']).map { |tag| tag['name'] }
          versions_tags = {}
          tags.each do |tag|
            clean_tag = tag.gsub(/^v(er)? ?/, '')
            versions_tags[Gem::Version.new(clean_tag)] = tag if Gem::Version.correct?(clean_tag)
          end
          version = versions_tags.keys.sort.last || '0.0.1'
          data = { :version => version }
          if version == '0.0.1'
            branches        = GitHub.branches(repo['html_url'])
            master_name     = repo['master_branch'] || 'master'
            master          = branches.find { |branch| branch['name'] == master_name }
            raise Informative, "Unable to find any commits on the master branch for the repository `#{repo['html_url']}`" unless master
            data[:ref_type] = ':commit'
            data[:ref]      = master['commit']['sha']
          else
            data[:ref_type] = ':tag'
            data[:ref]      = versions_tags[version]
          end
          data
        end

        def spec_template(data)
          <<-SPEC

Pod::Spec.new do |s|


  s.name         = "#{data[:name]}"
  s.version      = "#{data[:version]}"
  s.summary      = "#{data[:summary]}"

  s.description  = <<-DESC
                   DESC

  s.homepage     = "#{data[:homepage]}"



  s.license      = "MIT (example)"



  s.author             = { "#{data[:author_name]}" => "#{data[:author_email]}" }






  s.source       = { :git => "#{data[:source_url]}", #{data[:ref_type]} => "#{data[:ref]}" }



  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  s.exclude_files = "Classes/Exclude"














end
          SPEC
        end

        def semantic_versioning_notice(repo_id, repo)
          <<-EOS


I’ve recently added [#{repo}](https://github.com/CocoaPods/Specs/tree/master/#{repo}) to the [CocoaPods](https://github.com/CocoaPods/CocoaPods) package manager repo.

CocoaPods is a tool for managing dependencies for OSX and iOS Xcode projects and provides a central repository for iOS/OSX libraries. This makes adding libraries to a project and updating them extremely easy and it will help users to resolve dependencies of the libraries they use.

However, #{repo} doesn't have any version tags. I’ve added the current HEAD as version 0.0.1, but a version tag will make dependency resolution much easier.

[Semantic version](http://semver.org) tags (instead of plain commit hashes/revisions) allow for [resolution of cross-dependencies](https://github.com/CocoaPods/Specs/wiki/Cross-dependencies-resolution-example).

In case you didn’t know this yet; you can tag the current HEAD as, for instance, version 1.0.0, like so:

```
$ git tag -a 1.0.0 -m "Tag release 1.0.0"
$ git push --tags
```



After commiting the specification, consider opening a ticket with the template displayed above:
  - link:  https://github.com/#{repo_id}/issues/new
  - title: Please add semantic version tags
          EOS
        end
      end
    end
  end
end
