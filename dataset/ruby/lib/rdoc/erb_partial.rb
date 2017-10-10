
class RDoc::ERBPartial < ERB


  def set_eoutvar compiler, eoutvar = '_erbout'
    super

    compiler.pre_cmd = ["#{eoutvar} ||= ''"]
  end

end

