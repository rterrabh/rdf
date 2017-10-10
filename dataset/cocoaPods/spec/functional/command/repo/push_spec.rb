require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Command::Repo::Push do
    extend SpecHelper::Command
    extend SpecHelper::TemporaryRepos

    before do
      config.repos_dir = SpecHelper.tmp_repos_path
    end

    it "complains if it can't find the repo" do
      Dir.chdir(fixture('banana-lib')) do
        cmd = command('repo', 'push', 'missing_repo')
        cmd.expects(:check_if_master_repo)
        cmd.expects(:validate_podspec_files).returns(true)
        e = lambda { cmd.run }.should.raise Informative
        e.message.should.match(/repo not found/)
      end
    end

    it "complains if it can't find a spec" do
      repo_make('test_repo')
      e = lambda { run_command('repo', 'push', 'test_repo') }.should.raise Pod::Informative
      e.message.should.match(/Couldn't find any podspec/)
    end

    it "complains if it can't find the given podspec" do
      repo_make('test_repo')
      e = lambda { run_command('repo', 'push', 'test_repo', 'testspec.podspec') }.should.raise Pod::Informative
      e.message.should.match(/Couldn't find testspec\.podspec/)
    end

    it "it raises if the specification doesn't validate" do
      repo_make('test_repo')
      Dir.chdir(temporary_directory) do
        spec = "Spec.new do |s|; s.name = 'Broken'; s.version = '1.0' end"
        File.open('Broken.podspec',  'w') { |f| f.write(spec) }
        cmd = command('repo', 'push', 'test_repo')
        Validator.any_instance.stubs(:validated?).returns(false)

        e = lambda { cmd.run }.should.raise Pod::Informative
        e.message.should.match(/Broken.podspec.*does not validate/)
      end
    end

    it 'finds JSON podspecs' do
      repo_make('test_repo')

      Dir.chdir(temporary_directory) do
        File.open('JSON.podspec.json',  'w') { |f| f.write('{}') }
        cmd = command('repo', 'push', 'test_repo')
        cmd.send(:podspec_files).should == [Pathname('JSON.podspec.json')]
      end
    end

    #--------------------------------------#

    before do
      set_up_test_repo
      config.repos_dir = SpecHelper.tmp_repos_path

      @upstream = SpecHelper.temporary_directory + 'upstream'
      FileUtils.cp_r(test_repo_path, @upstream)
      Dir.chdir(test_repo_path) do
        `git remote add origin #{@upstream}`
        `git remote -v`
        `git fetch -q`
        `git branch --set-upstream-to=origin/master master`
      end

      # prepare the spec
      spec = (fixture('spec-repos') + 'test_repo/JSONKit/1.4/JSONKit.podspec').read
      spec_fix = spec.gsub(%r{https://github\.com/johnezang/JSONKit\.git}, fixture('integration/JSONKit').to_s)
      spec_add = spec.gsub(/'JSONKit'/, "'PushTest'")

      spec_clean = (fixture('spec-repos') + 'test_repo/BananaLib/1.0/BananaLib.podspec').read

      File.open(temporary_directory + 'JSONKit.podspec',  'w') { |f| f.write(spec_fix) }
      File.open(temporary_directory + 'PushTest.podspec', 'w') { |f| f.write(spec_add) }
      File.open(temporary_directory + 'BananaLib.podspec', 'w') { |f| f.write(spec_clean) }
    end

    it 'refuses to push if the repo is not clean' do
      Dir.chdir(test_repo_path) do
        `git remote set-url origin https://github.com/CocoaPods/Specs.git`
      end
      cmd = command('repo', 'push', 'master')
      e = lambda { cmd.run }.should.raise Pod::Informative
      e.message.should.match(/use the `pod trunk push` command/)
    end

    it 'refuses to push if the repo is not clean' do
      Dir.chdir(test_repo_path) do
        `touch DIRTY_FILE`
      end
      cmd = command('repo', 'push', 'master')
      cmd.expects(:validate_podspec_files).returns(true)
      e = lambda { cmd.run }.should.raise Pod::Informative
      e.message.should.match(/repo.*not clean/)
      (@upstream + 'PushTest/1.4/PushTest.podspec').should.not.exist?
    end

    it 'successfully pushes a spec' do
      cmd = command('repo', 'push', 'master')
      Dir.chdir(@upstream) { `git checkout -b tmp_for_push -q` }
      cmd.expects(:validate_podspec_files).returns(true)
      Dir.chdir(temporary_directory) { cmd.run }
      Pod::UI.output.should.include('[Add] PushTest (1.4)')
      Pod::UI.output.should.include('[Fix] JSONKit (1.4)')
      Pod::UI.output.should.include('[No change] BananaLib (1.0)')
      Dir.chdir(@upstream) { `git checkout master -q` }
      (@upstream + 'PushTest/1.4/PushTest.podspec').read.should.include('PushTest')
    end

    it 'initializes with default sources if no custom sources specified' do
      cmd = command('repo', 'push', 'master')
      cmd.instance_variable_get(:@source_urls).should.equal [@upstream.to_s]
    end

    it 'initializes with custom sources if specified' do
      cmd = command('repo', 'push', 'master', '--sources=test_repo2,test_repo1')
      cmd.instance_variable_get(:@source_urls).should.equal %w(test_repo2 test_repo1)
    end

    before do
      %i(prepare resolve_dependencies download_dependencies).each do |m|
        Installer.any_instance.stubs(m)
      end
      Installer.any_instance.stubs(:aggregate_targets).returns([])
      Installer.any_instance.stubs(:pod_targets).returns([])
      Validator.any_instance.stubs(:install_pod)
      Validator.any_instance.stubs(:check_file_patterns)
      Validator.any_instance.stubs(:validated?).returns(true)
      Validator.any_instance.stubs(:validate_url)
      Validator.any_instance.stubs(:validate_screenshots)
      Validator.any_instance.stubs(:xcodebuild).returns('')
    end

    it 'validates specs as frameworks by default' do
      Validator.any_instance.expects(:podfile_from_spec).with(:ios, nil, true).times(3)
      Validator.any_instance.expects(:podfile_from_spec).with(:osx, nil, true).twice
      Validator.any_instance.expects(:podfile_from_spec).with(:watchos, nil, true).twice

      cmd = command('repo', 'push', 'master')
      Dir.chdir(temporary_directory) { cmd.run }
    end

    it 'validates specs as libraries if requested' do
      Validator.any_instance.expects(:podfile_from_spec).with(:ios, nil, false).times(3)
      Validator.any_instance.expects(:podfile_from_spec).with(:osx, nil, false).twice
      Validator.any_instance.expects(:podfile_from_spec).with(:watchos, nil, false).twice

      cmd = command('repo', 'push', 'master', '--use-libraries')
      Dir.chdir(temporary_directory) { cmd.run }
    end
  end
end
