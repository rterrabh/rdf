require "singleton"
require 'sexp_processor'
require 'ruby_parser'


class StatementsCounter < SexpInterpreter
  include Singleton
  
  STATIC_FEATURES = [:call, :alias, :and, :argscat, :argspush, 
                     :array, :attrasgn, :back_ref, :begin, :block_arg,
                     :block_pass, :break, :case, :cdecl, :class,
                     :colon2, :colon3, :cvar, :cvasgn, :cvdecl,
                     :defined, :defn, :defs, :dot2, :dot3,
                     :dregx, :dregx_once, :dsym, :dxstr, :ensure,
                     :evstr, :false, :fcall, :file, :fixnum,
                     :flip2, :flip3, :float, :for, :gasgn,
                     :hash, :iasgn, :if, :iter, :lasgn,
                     :masgn, :match, :match2, :match3, :module,
                     :negate, :next, :not, :nth_ref, :number,
                     :op_asgn1, :op_asgn2, :op_asgn_and, :op_asgn_or, :or,
                     :postexe, :redo, :regex, :rescue, :retry,
                     :return, :sclass, :scope, :self, :splat,
                     :super, :svalue, :to_ary, :true, :undef,
                     :until, :vcall, :valias, :values, :when,
                     :while, :xstr, :yield, :zarray, :zsuper,
                     :block_pass, :postarg, :iter, :lambda,
                     :number, :opt_arg, :postexe, :super, :arglist,
                     :kwsplat
                    ]

  DYNAMIC_FEATURES = [:class_eval, :class_variable_get, :class_variable_set, :const_set, :const_get, 
                      :define_method, :eval, :instance_eval, :instance_exec, :instance_variable_get,
                      :instance_variable_set, :instance_exec, :module_eval, :send, :attr_reader, :attr_writer, :attr_accessor,
                      :require, :include
                     ]

  def initialize()
    super()
    self.default_method = "default_process"
    self.warn_on_default = false
    self.require_empty = false
  end

  def createDynamicStatementsCounter()
    counter = {}
    DYNAMIC_FEATURES.each do |dynamicStatements|
      counter[dynamicStatements] = 0
    end
    return counter
  end

  def count(files)
    @projectData = ProjectData.new
    @isMethodUsingDynamic = false
    @isLineWithDynamic = false
    @currentLine = 0
    files.each do |file|
      begin
        ast = RubyParser.new().parse(File.open(file).read)
        #puts ast.to_s
        process(ast)
      rescue ParseError, RuntimeError => e
        #puts "Error in file #{file}"
      end
    end
    return @projectData
  end
  
  def nextLine(exp)
    if(exp.line != @currentLine)
      @projectData.loc += 1
      @currentLine = exp.line
      @isLineWithDynamic = false
    end
  end

  def class_defined(exp)
    save = @methodMissingImplemented
    @projectData.totalClasses += 1
    @methodMissingImplemented = false
    default_process(exp)
    if(@methodMissingImplemented)
      @projectData.totalClassesWithMethodMissing += 1
    end
    @methodMissingImplemented = save
  end

  def method_defined(exp)
    save = @isMethodUsingDynamic
    if(exp[1] == :method_missing)
      @methodMissingImplemented = true
      @projectData.totalDynamicStatements += 1
    end
    @projectData.totalMethods += 1
    @isMethodUsingDynamic = false
    default_process(exp)
    if(@isMethodUsingDynamic)
      @projectData.totalMethodsUsingDynamic += 1
    end
    @isMethodUsingDynamic = save
  end

  def default_process(exp)
    if(STATIC_FEATURES.include?(exp[0]))
      @projectData.totalStatements += 1
    end
    nextLine(exp)
    exp.map {|subtree| process(subtree) if subtree.class == Sexp}
  end

  def process_call(exp)
    nextLine(exp)
    if(DYNAMIC_FEATURES.include?(exp[2]))
      @projectData.incrementDynamicStatements(exp[2])
      @isMethodUsingDynamic = true
      if(!@isLineWithDynamic)
        @projectData.locDynamic += 1
        @isLineWithDynamic = true
      end
    end
    default_process(exp)
  end


  def process_defs(exp)
    method_defined(exp)
  end

  def process_defn(exp)
    method_defined(exp)
  end

  def process_sdefn(exp)
    method_defined(exp)
  end

  def process_class(exp)
    class_defined(exp)
  end

  def process_sclass(exp)
    class_defined(exp)
  end

  def process_module(exp)
    class_defined(exp)
  end
end
