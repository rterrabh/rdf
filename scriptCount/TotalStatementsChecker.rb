require "singleton"
require 'sexp_processor'
require 'ruby_parser'


class TotalStatementsChecker < SexpProcessor
  include Singleton
  
  def checker(files)
    self.require_empty = false
    @totalStatements = 0
    files.each do |file|
      begin
        ast = RubyParser.new().parse(File.open(file).read)
        process(ast)
      rescue ParseError, RuntimeError => e
      end
    end
    return @totalStatements
  end
  
  def default_process(exp, isToCount)
    if(isToCount)
      @totalStatements += 1
    end
    exp.map {|subtree| process(subtree) if subtree.class == Sexp}
    exp
  end
  
  def process_call exp
    default_process(exp, true)
  end
    
  def process_alias exp
    default_process(exp, true)
  end

  def process_and exp
    default_process(exp, true)
  end

  def process_argscat exp
    default_process(exp, true)
  end

  def process_argspush exp
    default_process(exp, true)
  end

  def process_array exp
    default_process(exp, true)
  end

  def process_attrasgn exp
    default_process(exp, true)
  end

  def process_back_ref exp
    default_process(exp, true)
  end

  def process_begin exp
    default_process(exp, true)
  end

  def process_block_arg exp
    default_process(exp, true)
  end

  def process_block_pass exp
    default_process(exp, true)
  end

  def process_break exp
    default_process(exp, true)
  end

  def process_case exp
    default_process(exp, true)
  end

  def process_cdecl exp
    default_process(exp, true)
  end

  def process_class exp
    default_process(exp, true)
  end

  def process_colon2 exp
    default_process(exp, true)
  end

  def process_colon3 exp
    default_process(exp, true)
  end

  def process_cvar exp
    default_process(exp, true)
  end

  def process_cvasgn exp
    default_process(exp, true)
  end

  def process_cvdecl exp
    default_process(exp, true)
  end

  def process_defined exp
    default_process(exp, true)
  end

  def process_defn exp
    default_process(exp, true)
  end

  def process_defs exp
    default_process(exp, true)
  end

  def process_dot2 exp
    default_process(exp, true)
  end

  def process_dot3 exp
    default_process(exp, true)
  end

  def process_dregx exp
    default_process(exp, true)
  end

  def process_dregx_once exp
    default_process(exp, true)
  end

  def process_dsym exp
    default_process(exp, true)
  end

  def process_dxstr exp
    default_process(exp, true)
  end

  def process_ensure exp
    default_process(exp, true)
  end

  def process_evstr exp
    default_process(exp, true)
  end

  def process_false exp
    default_process(exp, true)
  end

  def process_fcall exp
    default_process(exp, true)
  end

  def process_file exp
    default_process(exp, true)
  end

  def process_fixnum exp
    default_process(exp, true)
  end

  def process_flip2 exp
    default_process(exp, true)
  end

  def process_flip3 exp
    default_process(exp, true)
  end

  def process_float exp
    default_process(exp, true)
  end

  def process_for exp
    default_process(exp, true)
  end

  def process_gasgn exp
    default_process(exp, true)
  end

  def process_hash exp
    default_process(exp, true)
  end

  def process_iasgn exp
    default_process(exp, true)
  end

  def process_if exp
    default_process(exp, true)
  end

  def process_iter exp
    default_process(exp, true)
  end

  def process_lasgn exp
    default_process(exp, true)
  end

  def process_masgn exp
    default_process(exp, true)
  end

  def process_match exp
    default_process(exp, true)
  end

  def process_match2 exp
    default_process(exp, true)
  end

  def process_match3 exp
    default_process(exp, true)
  end

  def process_module exp
    default_process(exp, true)
  end

  def process_negate exp
    default_process(exp, true)
  end

  def process_next exp
    default_process(exp, true)
  end

  def process_not exp
    default_process(exp, true)
  end

  def process_nth_ref exp
    default_process(exp, true)
  end

  def process_number exp
    default_process(exp, true)
  end

  def process_op_asgn1 exp
    default_process(exp, true)
  end

  def process_op_asgn2 exp
    default_process(exp, true)
  end

  def process_op_asgn_and exp
    default_process(exp, true)
  end

  def process_op_asgn_or exp
    default_process(exp, true)
  end

  def process_or exp
    default_process(exp, true)
  end

  def process_postexe exp
    default_process(exp, true)
  end

  def process_redo exp
    default_process(exp, true)
  end

  def process_regex exp
    default_process(exp, true)
  end

  def process_rescue exp
    default_process(exp, true)
  end

  def process_retry exp
    default_process(exp, true)
  end

  def process_return exp
    default_process(exp, true)
  end

  def process_sclass exp
    default_process(exp, true)
  end

  def process_scope exp
    default_process(exp, true)
  end

  def process_self exp
    default_process(exp, true)
  end

  def process_splat exp
    default_process(exp, true)
  end

  def process_super exp
    default_process(exp, true)
  end

  def process_svalue exp
    default_process(exp, true)
  end
  
  def process_to_ary exp
    default_process(exp, true)
  end

  def process_true exp
    default_process(exp, true)
  end

  def process_undef exp
    default_process(exp, true)
  end

  def process_until exp
    default_process(exp, true)
  end

  def process_vcall exp
    default_process(exp, true)
  end

  def process_valias exp
    default_process(exp, true)
  end

  def process_values exp
    default_process(exp, true)
  end

  def process_when exp
    default_process(exp, true)
  end

  def process_while exp
    default_process(exp, true)
  end

  def process_xstr exp
    default_process(exp, true)
  end

  def process_yield exp
    default_process(exp, true)
  end

  def process_zarray exp
    default_process(exp, true)
  end

  def process_zsuper exp
    default_process(exp, true)
  end

  def process_block_pass exp
    default_process(exp, true)
  end

  def process_postarg exp
    default_process(exp, true)
  end

  def process_iter exp
    default_process(exp, true)
  end

  def process_lambda exp
    default_process(exp, true)
  end

  def process_number exp
    default_process(exp, true)
  end

  def process_opt_arg exp
    default_process(exp, true)
  end

  def process_postexe exp
    default_process(exp, true)
  end

  def process_scope exp
    default_process(exp, true)
  end

  def process_super exp
    default_process(exp, true)
  end

  def process_arglist exp
    default_process(exp, true)
  end

  def process_kwsplat exp
    default_process(exp, true)
  end

  #not count
  def process_lit exp
    default_process(exp, false)
  end
  
end
