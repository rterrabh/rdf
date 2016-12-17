class Verificador


  def self.contemInstrucao?(instrucao, conteudo)
    instrucao = instrucao.to_sym
    if(instrucao == :send)
      return contemSend?(conteudo)
    elsif(instrucao == :instance_exec)
      return contemInstanceExec?(conteudo)
    elsif(instrucao == :instance_eval)
      return contemInstanceEval?(conteudo)
    elsif(instrucao == :eval)
      return contemEval?(conteudo)
    elsif(instrucao == :define_method)
      return contemDefineMethod?(conteudo)
    elsif(instrucao == :const_get)
      return contemConstGet?(conteudo)
    elsif(instrucao == :const_set)
      return contemConstSet?(conteudo)
    end
    return false
  end


  private

  def self.todasOcorrencias(procura, conteudo)
    index = 0
    ocorrencias = []
    while (!index.nil?)
      index = conteudo.index(procura, index)
      if(!index.nil?)
        ocorrencias << index
        index += procura.length
      end
    end
    return ocorrencias
  end

  def self.contemPadrao(instrucao, conteudo)
    alfabeto = "_abcdefghijklmnopqrstuvwxyz"
    qtdEncontrada = 0
    todasOcorrencias(instrucao, conteudo).each do |index|
      if (index >= 1 && alfabeto.index(conteudo[index-1]) != nil)
        next
      elsif (index + instrucao.length < conteudo.length && alfabeto.index(conteudo[index + instrucao.length]) != nil )
        next
      end
      qtdEncontrada += 1
    end
    return qtdEncontrada
  end

  def self.contemSend?(conteudo)
    if conteudo.include?("public_send")
      return 1
    end
    return contemPadrao("send", conteudo)
  end

  def self.contemInstanceExec?(conteudo)
    return contemPadrao("instance_exec", conteudo)
  end

  def self.contemInstanceEval?(conteudo)
    return contemPadrao("instance_eval", conteudo)
  end

  def self.contemEval?(conteudo)
    return contemPadrao("eval", conteudo)
  end

  def self.contemDefineMethod?(conteudo)
    return contemPadrao("define_method", conteudo)
  end

  def self.contemConstGet?(conteudo)
    return contemPadrao("const_get", conteudo)
  end

  def self.contemConstSet?(conteudo)
    return contemPadrao("const_set", conteudo)
  end
end
