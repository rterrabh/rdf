class Hbc::Container::Naked < Hbc::Container::Base
  def self.me?(criteria)
    false
  end

  def extract
    @command.run!('/usr/bin/ditto', :args => ['--', @path, @cask.staged_path.join(target_file)])
  end

  def target_file
    URI.decode(File.basename(@cask.url.path))
  end
end
