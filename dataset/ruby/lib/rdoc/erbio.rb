require 'erb'


class RDoc::ERBIO < ERB


  def initialize str, safe_level = nil, trim_mode = nil, eoutvar = 'io'
    super
  end


  def set_eoutvar compiler, io_variable
    compiler.put_cmd    = "#{io_variable}.write"
    compiler.insert_cmd = "#{io_variable}.write"
    compiler.pre_cmd    = []
    compiler.post_cmd   = []
  end

end

