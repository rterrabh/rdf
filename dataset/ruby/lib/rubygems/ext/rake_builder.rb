
class Gem::Ext::RakeBuilder < Gem::Ext::Builder

  def self.build(extension, directory, dest_path, results, args=[], lib_dir=nil)
    if File.basename(extension) =~ /mkrf_conf/i then
      cmd = "#{Gem.ruby} #{File.basename extension}"
      cmd << " #{args.join " "}" unless args.empty?
      run cmd, results
    end

    dest_path = '"' + dest_path.to_s + '"' if dest_path.to_s.include?(' ')

    rake = ENV['rake']

    rake ||= begin
               "#{Gem.ruby} -rubygems #{Gem.bin_path('rake', 'rake')}"
             rescue Gem::Exception
             end

    rake ||= Gem.default_exec_format % 'rake'

    cmd = "#{rake} RUBYARCHDIR=#{dest_path} RUBYLIBDIR=#{dest_path}" # ENV is frozen

    run cmd, results

    results
  end

end

