
class Gem::Ext::ConfigureBuilder < Gem::Ext::Builder

  def self.build(extension, directory, dest_path, results, args=[], lib_dir=nil)
    unless File.exist?('Makefile') then
      cmd = "sh ./configure --prefix=#{dest_path}"
      cmd << " #{args.join ' '}" unless args.empty?

      run cmd, results
    end

    make dest_path, results

    results
  end

end

