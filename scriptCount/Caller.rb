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

  def process_module(exp)
    moduleName = getClassName(exp)
    if (@methodName == moduleName)
      puts "#{@currentFile}.#{exp.line} (MODULE)"
    end
    default_process(exp)    
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

  #activeadmin
#  files_to_research << "../dataset/activeadmin/**/lib/**/*.rb"

  #diaspora
#  files_to_research << "../dataset/diaspora/**/lib/**/*.rb"
#  files_to_research << "../dataset/diaspora/app/**/*.rb"
#  files_to_research << "../dataset/diaspora/config/**/*.rb"

  #discourse
#  files_to_research << "../dataset/discourse/**/lib/**/*.rb"
#  files_to_research << "../dataset/discourse/app/**/*.rb"
#  files_to_research << "../dataset/discourse/config/**/*.rb"

  #gitlab
#  files_to_research << "../dataset/gitlabhq/**/lib/**/*.rb"
#  files_to_research << "../dataset/gitlabhq/app/**/*.rb"
#  files_to_research << "../dataset/gitlabhq/config/**/*.rb"

  #homebrew
#  files_to_research << "../dataset/homebrew/**/lib/**/*.rb"

  #paperclip
#  files_to_research << "../dataset/paperclip/**/lib/**/*.rb"

  #rails
#  files_to_research << "../dataset/rails/**/lib/**/*.rb"

  #rails_admin
#  files_to_research << "../dataset/rails_admin/**/lib/**/*.rb"

  #ruby
#  files_to_research << "../dataset/ruby/**/lib/**/*.rb"

  #spree
#  files_to_research << "../dataset/spree/**/lib/**/*.rb"
#  files_to_research << "../dataset/spree/api/**/*.rb"
#  files_to_research << "../dataset/spree/backend/**/*.rb"
#  files_to_research << "../dataset/spree/core/**/*.rb"

  #cancan
#  files_to_research << "../dataset/cancan/**/lib/**/*.rb"

  #capistrano
#  files_to_research << "../dataset/capistrano/**/lib/**/*.rb"

  #capybara
#  files_to_research << "../dataset/capybara/**/lib/**/*.rb"

  #carrierwave
#  files_to_research << "../dataset/carrierwave/**/lib/**/*.rb"

  #cocoapods
#  files_to_research << "../dataset/cocoaPods/**/lib/**/*.rb"

  #devdocs
#  files_to_research << "../dataset/devdocs/**/lib/**/*.rb"

  #devise
#  files_to_research << "../dataset/devise/**/lib/**/*.rb"
#  files_to_research << "../dataset/devise/**/app/**/*.rb"

  #fpm
#  files_to_research << "../dataset/fpm/**/lib/**/*.rb"

  #grape
#  files_to_research << "../dataset/grape/**/lib/**/*.rb"

  #homebrew-cask
#  files_to_research << "../dataset/homebrew-cask/**/lib/**/*.rb"

  #huginn
#  files_to_research << "../dataset/huginn/**/lib/**/*.rb"
#  files_to_research << "../dataset/huginn/**/app/**/*.rb"

  #jekyll
#  files_to_research << "../dataset/jekyll/**/lib/**/*.rb"

  #octopress
#  files_to_research << "../dataset/octopress/**/plugins/**/*.rb"

  #resque
#  files_to_research << "../dataset/resque/**/lib/**/*.rb"

  #sass
 files_to_research << "../dataset/sass/**/lib/**/*.rb"

  #simple form
#  files_to_research << "../dataset/simple_form/**/lib/**/*.rb"

  #vagrant
#  files_to_research << "../dataset/vagrant/**/lib/**/*.rb"

  #whenever
#  files_to_research << "../dataset/whenever/**/lib/**/*.rb"

  Caller.instance.find(Util.extractFiles(files_to_research), ARGV[0])
end
