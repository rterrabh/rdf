require "singleton"
require 'sexp_processor'
require 'ruby_parser'
require_relative '../util/Util'

class Caller < SexpInterpreter
  include Singleton

  def initialize()
    super()
    self.default_method = "default_process"
    self.warn_on_default = false
    self.require_empty = false
  end

  def find(files, methodName)
    @methodName = methodName.to_sym()
    files.each do |file|
      @currentFile = File.absolute_path(file)
      begin
        ast = RubyParser.new().parse(File.open(file).read)
        process(ast)
      rescue ParseError, RuntimeError => e
        puts "Error in file: #{file}, cause: #{e}" 
      end
    end
  end
  
  def default_process(exp)
    exp.map {|subtree| process(subtree) if subtree.class == Sexp}
  end

  def process_defn(exp)
    if(exp[1] == @methodName)
      puts "#{@currentFile}.#{exp.line} (DEF)"
    end
    default_process(exp)
  end

  def process_sdefn(exp)
    if(exp[1] == @methodName)
      puts "#{@currentFile}.#{exp.line} (DEF)"
    end
    default_process(exp)
  end

  def process_call(exp)
    if(exp[2] == @methodName)
      puts "#{@currentFile}.#{exp.line} (CALL)"
    end
    default_process(exp)
  end
end

if(ARGV.size >= 0)
  files_to_research = []
  files_to_research << "../dataset/homebrew-cask/**/lib/**/*.rb"
  Caller.instance.find(Util.extractFiles(files_to_research), ARGV[0])
end
