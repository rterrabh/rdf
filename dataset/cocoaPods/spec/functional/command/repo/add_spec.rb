require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo::Add do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it 'adds a spec-repo' do
      run_command('repo', 'add', 'private', test_repo_path)
      Dir.chdir(config.repos_dir + 'private') do
        `git config --get remote.origin.url`.chomp.should == test_repo_path.to_s
      end
    end

    it 'adds a spec-repo with a specified branch' do
      repo1 = repo_make('repo1')
      Dir.chdir(repo1) do
        `git checkout -b my-branch >/dev/null 2>&1`
        `git checkout master >/dev/null 2>&1`
      end
      repo2 = command('repo', 'add', 'repo2', repo1.to_s, 'my-branch')
      repo2.run
      Dir.chdir(repo2.dir) { `git symbolic-ref HEAD` }.should.include? 'my-branch'
    end

    it 'adds a spec-repo by creating a shallow clone' do
      Dir.chdir(test_repo_path) do
        `echo 'touch' > touch && git add touch && git commit -m 'updated'`
      end
      # Need to use file:// to test local use of --depth=1
      run_command('repo', 'add', 'private', '--shallow', "file://#{test_repo_path}")
      Dir.chdir(config.repos_dir + 'private') do
        `git log --pretty=oneline`.strip.split("\n").size.should == 1
      end
    end
  end
end
