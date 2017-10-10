
require 'rubygems/package'
require 'rubygems/installer'


class Gem::Validator

  include Gem::UserInteraction

  def initialize # :nodoc:
    require 'find'
  end


  def verify_gem(gem_data)
  end


  def verify_gem_file(gem_path)
    open gem_path, Gem.binary_mode do |file|
      gem_data = file.read
      verify_gem gem_data
    end
  rescue Errno::ENOENT, Errno::EINVAL
    raise Gem::VerificationError, "missing gem file #{gem_path}"
  end

  private

  def find_files_for_gem(gem_directory)
    installed_files = []

    Find.find gem_directory do |file_name|
      fn = file_name[gem_directory.size..file_name.size-1].sub(/^\//, "")
      installed_files << fn unless
        fn =~ /CVS/ || fn.empty? || File.directory?(file_name)
    end

    installed_files
  end

  public


  ErrorData = Struct.new :path, :problem do
    def <=> other # :nodoc:
      return nil unless self.class === other

      [path, problem] <=> [other.path, other.problem]
    end
  end


  def alien(gems=[])
    errors = Hash.new { |h,k| h[k] = {} }

    Gem::Specification.each do |spec|
      next unless gems.include? spec.name unless gems.empty?
      next if spec.default_gem?

      gem_name      = spec.file_name
      gem_path      = spec.cache_file
      spec_path     = spec.spec_file
      gem_directory = spec.full_gem_path

      unless File.directory? gem_directory then
        errors[gem_name][spec.full_name] =
          "Gem registered but doesn't exist at #{gem_directory}"
        next
      end

      unless File.exist? spec_path then
        errors[gem_name][spec_path] = "Spec file missing for installed gem"
      end

      begin
        verify_gem_file(gem_path)

        good, gone, unreadable = nil, nil, nil, nil

        open gem_path, Gem.binary_mode do |file|
          package = Gem::Package.new gem_path

          good, gone = package.contents.partition { |file_name|
            File.exist? File.join(gem_directory, file_name)
          }

          gone.sort.each do |path|
            errors[gem_name][path] = "Missing file"
          end

          good, unreadable = good.partition { |file_name|
            File.readable? File.join(gem_directory, file_name)
          }

          unreadable.sort.each do |path|
            errors[gem_name][path] = "Unreadable file"
          end

          good.each do |entry, data|
            begin
              next unless data # HACK `gem check -a mkrf`

              source = File.join gem_directory, entry['path']

              open source, Gem.binary_mode do |f|
                unless f.read == data then
                  errors[gem_name][entry['path']] = "Modified from original"
                end
              end
            end
          end
        end

        installed_files = find_files_for_gem(gem_directory)
        extras = installed_files - good - unreadable

        extras.each do |extra|
          errors[gem_name][extra] = "Extra file"
        end
      rescue Gem::VerificationError => e
        errors[gem_name][gem_path] = e.message
      end
    end

    errors.each do |name, subhash|
      errors[name] = subhash.map do |path, msg|
        ErrorData.new path, msg
      end.sort
    end

    errors
  end
end

