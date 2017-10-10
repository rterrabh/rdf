require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Executable do
    it 'shows the actual command on failure' do
      e = lambda do
        Executable.execute_command('false',
                                   [''], true)
      end.should.raise Informative
      e.message.should.match(/false/)
    end

    it 'should support spaces in the full path of the command' do
      cmd = '/Spa ces/are"/fun/false'
      File.expects(:file?).with(cmd).returns(true)
      File.expects(:executable?).with(cmd).returns(true)
      result = mock
      result.stubs(:success?).returns(true)

      Open3.expects(:popen3).with('/Spa ces/are"/fun/false').once.returns(result)
      Executable.execute_command(cmd, [], true)
    end

    it "doesn't hang when the spawned process forks a zombie process with the same STDOUT and STDERR" do
      cmd = ['-e', <<-RB]
        Process.fork { Process.daemon(nil, true); sleep(4) }
        puts 'out'
      RB
      Timeout.timeout(2) do
        Executable.execute_command('ruby', cmd, true).should == "out\n"
      end
    end

    it 'returns the right output' do
      cmd = ['-e', <<-RB]
        puts 'foo'
        puts 'bar'
      RB
      Executable.execute_command('ruby', cmd, true).should == "foo\nbar\n"
    end

    it 'handles an EOFError' do
      cmd = ['-e', <<-RB]
        puts 'foo'
        print 'bar'
      RB
      Executable.execute_command('ruby', cmd, true).should == "foo\nbar#{$/}"
    end

    it 'handles a large amount of output' do
      cmd = ['-e', <<-RB]
        puts File.read(#{__FILE__.inspect})
      RB
      Executable.execute_command('ruby', cmd, true).should == File.read(__FILE__)
    end

    it 'handles carriage returns' do
      cmd = ['-e', <<-RB]
        print "foo\\rbar\\nbaz\\r"
      RB
      Executable.execute_command('ruby', cmd, true).should == "foo\rbar\nbaz\r"
    end

    it 'prints the correct output to the console' do
      io = ''
      UI.indentation_level = 1
      config.verbose = true
      Executable::Indenter.any_instance.stubs(:io).returns(io)
      cmd = ['-e', <<-RB]
        3.times { |i| puts i }
      RB
      Executable.execute_command('ruby', cmd, true)
      io.should == " 0\n 1\n 2\n"
    end

    describe Executable::Indenter do
      it 'indents any appended strings' do
        UI.indentation_level = 4

        io = StringIO.new
        indenter = Executable::Indenter.new(io)

        indenter << 'hello'

        io.string.should == '    hello'
      end
    end
  end
end
