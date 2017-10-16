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
    i = 0
    files.each do |file|
      i += 1
      @currentFile = File.absolute_path(file)
      begin
        ast = RubyParser.new().parse(File.open(file).read)
        #puts ast.to_s
        process(ast)
      rescue ParseError, RuntimeError => e
        puts "Error in file: #{file}, cause: #{e}" 
      end
    end
    puts i
  end
  

  def getClassName(exp)
    if(exp[1].class == Sexp && !exp[2].nil?)
      return "#{getClassName(exp[1])}::#{exp[2]}".to_sym
    elsif(exp[1].class == Sexp && exp[2].nil?)
      return "#{getClassName(exp[1])}".to_sym
    else
      return "#{exp[1]}".to_sym
    end
  end

  def default_process(exp)
    exp.map {|subtree| process(subtree) if subtree.class == Sexp}
  end

  def process_sclass(exp)
    className = getClassName(exp)
    if (@methodName == className)
      puts "#{@currentFile}.#{exp.line} (CLASS)"
    end
    default_process(exp)
  end

  def process_class(exp)
    className = getClassName(exp)
    if (@methodName == className)
      puts "#{@currentFile}.#{exp.line} (CLASS)"
    end
    default_process(exp)
  end

  def process_cdecl(exp)
    if(exp[1] == @methodName)
      puts "#{@currentFile}.#{exp.line} (CDECL)"
    end
    default_process(exp)
  end

  def process_defn(exp)
    if(exp[1] == @methodName)
      puts "#{@currentFile}.#{exp.line} (DEF)"
    end
    default_process(exp)
  end

  def process_sdefn(exp)
    puts exp[1]
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
  files_to_research << "../dataset/cancan/**/lib/**/*.rb"
  #files_to_research << "/home/elderjr/Documents/test.rb"
  Caller.instance.find(Util.extractFiles(files_to_research), ARGV[0])
end
