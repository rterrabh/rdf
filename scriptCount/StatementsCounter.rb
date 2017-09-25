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

  DYNAMIC_FEATURES = [:const_set, :const_get, :define_method, :eval, :instance_eval, :instance_exec, :send]

  def initialize()
    super()
    self.default_method = "default_process"
    self.warn_on_default = false
  end

  def createDynamicStatementsCounter()
    counter = {}
    DYNAMIC_FEATURES.each do |dynamicStatements|
      counter[dynamicStatements] = 0
    end
    return counter
  end

  def count(files)
    self.require_empty = false
    @totalStatements = 0
    @totalDynamicStatements = 0
    @totalMethods = 0
    @totalMethodsUsingDynamic = 0
    @isMethodUsingDynamic = false
    @dynamicStatements = createDynamicStatementsCounter()
    files.each do |file|
      begin
        ast = RubyParser.new().parse(File.open(file).read)
#        puts ast.to_s
        process(ast)
      rescue ParseError, RuntimeError => e
      end
    end
    if(@totalMethods != 0)
      percMethodsUsingDynamic = ((@totalMethodsUsingDynamic.to_f / @totalMethods.to_f) * 100).round(2)
    else
      percMethodsUsingDynamic = 0
    end
    return @totalStatements, @totalDynamicStatements, percMethodsUsingDynamic, @dynamicStatements
  end
  
  def method_defined(exp)
    @totalMethods += 1
    @isMethodUsingDynamic = false
    default_process(exp)
    if(@isMethodUsingDynamic)
      @totalMethodsUsingDynamic += 1
    end
    @isMethodUsingDynamic = false
  end

  def default_process(exp)
    if(STATIC_FEATURES.include?(exp[0]))
      @totalStatements += 1
    end
    exp.map {|subtree| process(subtree) if subtree.class == Sexp}
  end

  def process_call(exp)
    if(DYNAMIC_FEATURES.include?(exp[2]))
      @totalDynamicStatements += 1
      @dynamicStatements[exp[2]] += 1
      @isMethodUsingDynamic = true      
    end
    default_process(exp)
  end

  def process_defn(exp)
    method_defined(exp)
  end

  def process_defs(exp)
    method_defined(exp)
  end
end
