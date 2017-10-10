

HostInfo = Struct.new(:name, :webdir, :pkgdir)


class CompositePublisher # :nodoc:
  def initialize
    @publishers = []
  end

  def add(pub)
    @publishers << pub
  end

  def upload
    @publishers.each { |p| p.upload }
  end
end

class SshDirPublisher # :nodoc: all
  def initialize(host, remote_dir, local_dir)
    @host = host
    @remote_dir = remote_dir
    @local_dir = local_dir
  end

  def upload
    run %{scp -rq #{@local_dir}/* #{@host}:#{@remote_dir}}
  end
end

class SshFreshDirPublisher < SshDirPublisher # :nodoc: all
  def upload
    run %{ssh #{@host} rm -rf #{@remote_dir}} rescue nil
    run %{ssh #{@host} mkdir #{@remote_dir}}
    super
  end
end

class SshFilePublisher # :nodoc: all
  def initialize(host, remote_dir, local_dir, *files)
    @host = host
    @remote_dir = remote_dir
    @local_dir = local_dir
    @files = files
  end

  def upload
    @files.each do |fn|
      run %{scp -q #{@local_dir}/#{fn} #{@host}:#{@remote_dir}}
    end
  end
end
