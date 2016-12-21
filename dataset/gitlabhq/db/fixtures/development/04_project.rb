require 'sidekiq/testing'

Sidekiq::Testing.inline! do
  Gitlab::Seeder.quiet do
    project_urls = [
      'https://github.com/documentcloud/underscore.git',
      'https://gitlab.com/gitlab-org/gitlab-ce.git',
      'https://gitlab.com/gitlab-org/gitlab-ci.git',
      'https://gitlab.com/gitlab-org/gitlab-shell.git',
      'https://gitlab.com/gitlab-org/gitlab-test.git',
      'https://github.com/twitter/flight.git',
      'https://github.com/twitter/typeahead.js.git',
      'https://github.com/h5bp/html5-boilerplate.git',
      'https://github.com/google/material-design-lite.git',
      'https://github.com/jlevy/the-art-of-command-line.git',
      'https://github.com/FreeCodeCamp/freecodecamp.git',
      'https://github.com/google/deepdream.git',
      'https://github.com/jtleek/datasharing.git',
      'https://github.com/WebAssembly/design.git',
      'https://github.com/airbnb/javascript.git',
      'https://github.com/tessalt/echo-chamber-js.git',
      'https://github.com/atom/atom.git',
      'https://github.com/ipselon/react-ui-builder.git',
      'https://github.com/mattermost/platform.git',
      'https://github.com/purifycss/purifycss.git',
      'https://github.com/facebook/nuclide.git',
      'https://github.com/wbkd/awesome-d3.git',
      'https://github.com/kilimchoi/engineering-blogs.git',
      'https://github.com/gilbarbara/logos.git',
      'https://github.com/gaearon/redux.git',
      'https://github.com/awslabs/s2n.git',
      'https://github.com/arkency/reactjs_koans.git',
      'https://github.com/twbs/bootstrap.git',
      'https://github.com/chjj/ttystudio.git',
      'https://github.com/DrBoolean/mostly-adequate-guide.git',
      'https://github.com/octocat/Spoon-Knife.git',
      'https://github.com/opencontainers/runc.git',
      'https://github.com/googlesamples/android-topeka.git'
    ]

    # You can specify how many projects you need during seed execution
    size = if ENV['SIZE'].present?
             ENV['SIZE'].to_i
           else
             8
           end


    project_urls.first(size).each_with_index do |url, i|
      group_path, project_path = url.split('/')[-2..-1]

      group = Group.find_by(path: group_path)

      unless group
        group = Group.new(
          name: group_path.titleize,
          path: group_path
        )
        group.description = FFaker::Lorem.sentence
        group.save

        group.add_owner(User.first)
      end

      project_path.gsub!(".git", "")

      params = {
        import_url: url,
        namespace_id: group.id,
        name: project_path.titleize,
        description: FFaker::Lorem.sentence,
        visibility_level: Gitlab::VisibilityLevel.values.sample
      }

      project = Projects::CreateService.new(User.first, params).execute

      if project.valid?
        print '.'
      else
        puts project.errors.full_messages
        print 'F'
      end
    end
  end
end
