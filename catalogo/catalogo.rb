require_relative 'item'
class Catalogo

  attr_reader :items
  attr_writer :total_arquivos

  def initialize()
    @items = {}
    @total_arquivos = 0
  end

  def add_item(name)
    if !@items.has_key?(name)
      @items[name] = Item.new(name)
    end
  end

  def increase_classification(item_name, classification_name)
    if !@items.has_key?(item_name)
      add_item(item_name)
    end
    @items[item_name].increase_classification(classification_name)
  end

  def export(nome_arquivo)
    classificacoes_geral = {}
    total_geral = 0
    conteudo = "Instrucao;"
    classificacoes = ["VERY LOW","LOW","MEDIUM","HIGH","VERY HIGH", "spec VERY LOW", "spec LOW", "spec MEDIUM", "spec HIGH", "spec VERY HIGH"]
    classificacoes.each do |classificacao|
      conteudo += "#{classificacao};"
    end
    conteudo += "\n"
    @items.each do |inst, item|
      total = 0
      linhaOcorrencias = "#{inst};"
      classificacoes.each do |classificacao|
        classificacao_inst = "#{inst} #{classificacao}"
        ocorrencias = item.get_ocorrencias(classificacao_inst)
        linhaOcorrencias += "#{ocorrencias};"
        total += ocorrencias
        if classificacoes_geral.has_key? classificacao
          classificacoes_geral[classificacao] += ocorrencias
        else
          classificacoes_geral[classificacao] = ocorrencias
        end
      end
      conteudo += "#{linhaOcorrencias}\n\n"
      total_geral += total
    end
    linhaOcorrencias = "Análise geral (Total de arquivos analisados: #{@total_arquivos}):;"
    classificacoes.each do |classificacao|
      linhaOcorrencias += "#{classificacoes_geral[classificacao]};"
    end
    conteudo += "#{linhaOcorrencias}\n"
    if nome_arquivo.nil?
      csv = File.new("output.csv","w")
    else
      csv = File.new(nome_arquivo+".csv","w")
    end
    csv.write(conteudo)
    csv.close
  end
  
  def show_catalog
    classificacoes_geral = {}
    total_geral = 0
    @items.each do |inst, item|
      puts "#{create_title(inst)}"
      total = 0
      item.classifications.sort.each do |classificacao, ocorrencias|
        puts "  #{classificacao}: #{ocorrencias}"
        total += ocorrencias
        classificacao = classificacao.sub("#{inst} ","")
        if classificacoes_geral.has_key? classificacao
          classificacoes_geral[classificacao] += ocorrencias
        else
          classificacoes_geral[classificacao] = ocorrencias
        end
      end
      total_geral += total
      puts "  Total: #{total}"
    end
    puts "#{create_title("Porcentagens")}"
    classificacoes_geral.sort.each do |key, value|
      puts "  #{key}: #{value} -> #{((value / total_geral.to_f) * 100).round(2)}%"
    end
    puts "=" * 80
  end

  def create_title(title)
    total_caracter = 78 - title.size
    new_title_caracter = "=" * (total_caracter/2)
    if(total_caracter % 2 == 0)
      return "#{new_title_caracter} #{title} #{new_title_caracter}"
    else
      return "#{new_title_caracter} #{title} #{new_title_caracter}="
    end

  end
  private :create_title
end