require 'rubygems'

class Hbc::Source::PathBase


  def self.path_for_query(query)
    path_string = "#{query}"
    path_string.concat('.rb') unless path_string.match(%r{\.rb\Z}i)
    Pathname.new(path_string)
  end

  attr_reader :path

  def initialize(path)
    @path = Pathname(path).expand_path
  end

  def load
    raise Hbc::CaskError.new "File '#{path}' does not exist"      unless path.exist?
    raise Hbc::CaskError.new "File '#{path}' is not readable"     unless path.readable?
    raise Hbc::CaskError.new "File '#{path}' is not a plain file" unless path.file?
    begin


      cask_contents = File.open(path, 'rb') do |handle|
        contents = handle.read
        if defined?(Encoding)
          contents.force_encoding('UTF-8')
        else
          contents
        end
      end

      cask_contents.sub!(%r{\A(\s*\#[^\n]*\n)+}, '');
      if %r{\A\s*cask\s+:v([\d_]+)(test)?\s+=>\s+([\'\"])(\S+?)\3(?:\s*,\s*|\s+)do\s*\n}.match(cask_contents)
        dsl_version_string = $1
        is_test = ! $2.nil?
        header_token = $4
        dsl_version = Gem::Version.new(dsl_version_string.gsub('_','.'))
        superclass_name = is_test ? 'Hbc::TestCask' : 'Hbc::Cask'
        cask_contents.sub!(%r{\A[^\n]+\n}, "class #{cask_class_name} < #{superclass_name}\n")
        minimum_dsl_version = Gem::Version.new('1.0')
        unless dsl_version >= minimum_dsl_version
          raise Hbc::CaskInvalidError.new(cask_token, "Bad header line: 'v#{dsl_version_string}' is less than required minimum version '#{minimum_dsl_version}'")
        end
        if header_token != cask_token
          raise Hbc::CaskInvalidError.new(cask_token, "Bad header line: '#{header_token}' does not match file name")
        end
      else
        raise Hbc::CaskInvalidError.new(cask_token, "Bad header line: parse failed")
      end

      begin
        #nodyna <const_get-2858> <CG COMPLEX (change-prone variable)>
        Object.const_get(cask_class_name)
      rescue NameError
        #nodyna <eval-2859> <EV COMPLEX (change-prone variables)>
        eval(cask_contents, TOPLEVEL_BINDING)
      end

    rescue Hbc::CaskError, StandardError, ScriptError => e
      e.message.concat(" while loading '#{path}'")
      raise e
    end
    begin
      #nodyna <const_get-2860> <CG COMPLEX (change-prone variable)>
      Object.const_get(cask_class_name).new(path)
    rescue Hbc::CaskError, StandardError, ScriptError => e
      e.message.concat(" while instantiating '#{cask_class_name}' from '#{path}'")
      raise e
    end
  end

  def cask_token
    path.basename.to_s.sub(/\.rb/, '')
  end

  def cask_class_name
    'KlassPrefix'.concat cask_token.split('-').map(&:capitalize).join
  end

  def to_s
    path.to_s
  end
end
