require_relative 'catalogo/catalogo'
require_relative 'verificador/Verificador'

class Nodyna

  def option(files_to_research, comandos)
    puts "#{"="*32} NODYNA OUTPUT #{"="*33}"

    argumentos = define_argumentos(comandos)
    if argumentos[:comando].nil?
      show_help
      puts "#{"="*37} END #{"="*38}"
      return
    elsif argumentos[:comando] == "setup"
      ocorrencias = hash_ocorrencias
      block = proc{|rbfile| setup(rbfile, ocorrencias)}
    elsif argumentos[:comando] == "show_classifications" || argumentos[:comando] == "export"
      catalogo = create_catalogo
      block = proc{|rbfile| build_catalogo(rbfile, catalogo)}
    elsif argumentos[:comando] == "show_locations_without_classification"
      instrucao = argumentos[:args].empty? ? nil : argumentos[:args][0]
      block = proc{|rbfile| show_location_without_classification(rbfile, instrucao, argumentos[:analyse])}
    elsif argumentos[:comando] == "show_locations"
      instrucao = argumentos[:args].empty? ? nil : argumentos[:args][0]
      classificacao = argumentos[:args].empty? ? nil : argumentos[:args][1]
      block = proc{|rbfile| show_location(rbfile, instrucao, classificacao, argumentos[:analyse])}
    elsif argumentos[:comando] == "change_classification"
      old_classification = argumentos[:args].empty? ? nil : argumentos[:args][0]
      new_classification = argumentos[:args].empty? ? nil : argumentos[:args][1]
      block = proc{|rbfile| change_classification(rbfile, old_classification, new_classification)}
    end

    #monta todos os arquivos para serem lidos
    dirs = Array.new
    files_to_research.each do |rbfiles|
      dirs  += Dir.glob(rbfiles)
    end
    dirs.flatten!
    puts "Total files: #{dirs.size}"
    dirs.each do |rbfile|
      block.call(rbfile)
    end

    if argumentos[:comando] == "show_classifications"
      catalogo.total_arquivos = dirs.size
      catalogo.show_catalog
    elsif argumentos[:comando] == "export"
      catalogo.total_arquivos = dirs.size
      nome_arquivo = argumentos[:args].empty? ? nil : argumentos[:args][0]
      catalogo.export nome_arquivo
    end
    puts "#{"="*37} END #{"="*38}"
  end

  # métodos de show_classes
  def create_catalogo()
    catalogo =  Catalogo.new
    catalogo.add_item("const_get")
    catalogo.add_item("const_set")
    catalogo.add_item("eval")
    catalogo.add_item("define_method")
    catalogo.add_item("instance_eval")
    catalogo.add_item("instance_exec")
    catalogo.add_item("send")
    return catalogo
  end

  def build_catalogo(rbfile, catalogo)
    File.open(rbfile, 'r').each do |line|
      if line.include? "#nodyna"
        instruction = get_instruction(line)
        classification = get_classification(line)
        catalogo.increase_classification(instruction, classification)
      end
    end
  end

  #métodos de change_classification
  def change_classification(rbfile, old_classification, new_classification)
    new_file = ""
    File.open(rbfile, 'r').each do |line|
      if line.include? "#nodyna" 
        if get_classification(line) == old_classification
          new_file += line.gsub(old_classification, new_classification)
        else
          new_file = "#{new_file}#{line}"          
        end
      else
        new_file = "#{new_file}#{line}"
      end
    end
    fh = File.open(rbfile, 'w')
    fh.puts new_file
    fh.close
  end

  #métodos de show_location
  def show_location(rbfile, instruction_type, classification, analyse)
    number = 0
    found_the_instruction = false
    File.open(rbfile, 'r').each do |line|
      number += 1
      if line.include? "#nodyna"
        if instruction_type and classification
          if get_instruction(line) == instruction_type and get_classification(line) == classification
            puts "#{rbfile}.#{number}.#{get_classification(line)}.#{get_ID(line)}"
            found_the_instruction = true
          end
        elsif instruction_type
          if get_instruction(line) == instruction_type
            puts "#{rbfile}.#{number}.#{get_classification(line)}.#{get_ID(line)}"
            found_the_instruction = true
          end
        elsif classification
          if get_classification(line) == classification
            puts "#{rbfile}.#{number}.#{get_classification(line)}.#{get_ID(line)}"
            found_the_instruction = true
          end
        end
      end
    end
    if analyse and found_the_instruction
      print "Write 'o' to open the file or anything to jump the file: "
      input = $stdin.gets
      if input == "o\n"
        system ("gedit #{rbfile}")
      end
    end
  end

  #métodos de show_location_without_classification
  def show_location_without_classification(rbfile, instruction_type, analyse)
    show_location(rbfile, instruction_type, "not yet classified", analyse)
  end


  #métodos do setup
  def setup(rbfile, ocorrencias)
    new_file = ""
    save_file = true
    File.open(rbfile, 'r').each do |line|
      if line.lstrip[0] != "#"
        ocorrencias.each do |key, value|
          qtdEncontrada = Verificador.contemInstrucao?(key, line)
          for i in 1..qtdEncontrada
            ocorrencias[key] += 1
            new_file = "#{new_file}#{indentation(line)}#nodyna <ID:#{key}-#{ocorrencias[key]}> <not yet classified>\n"
          end
        end
      elsif line.include? "nodyna"
        save_file = false
        break
      end
      new_file = "#{new_file}#{line}"
    end
    if save_file
      fh = File.open(rbfile, 'w')
      fh.puts new_file
      fh.close
    end
  end

  def hash_ocorrencias
    ocorrencias = Hash.new
    ocorrencias[:send] = 0
    ocorrencias[:const_get] = 0
    ocorrencias[:const_set] = 0
    ocorrencias[:define_method] = 0
    ocorrencias[:instance_eval] = 0
    ocorrencias[:instance_exec] = 0
    ocorrencias[:eval] = 0
    return ocorrencias
  end


  #métodos para pegar informações da linha com comentário #nodyna
  def get_ID(line)
    substring = line.match(/<([^>]*)> <([^>]*)>/)
    substring[1]
  end

  def get_instruction(line)
    id = get_ID(line)
    str1_markerstring = ":"
    str2_markerstring = "-"
    id[/#{str1_markerstring}(.*?)#{str2_markerstring}/m, 1]
  end

  def get_classification(line)
    substring = line.match(/<([^>]*)> <([^>]*)>/)
    substring[2]
  end


  #método para mostrar a ajuda
  def show_help
    puts "Help:"
    puts "setup: vai procurar todas as instruções Ruby e colocar um comentário \n       padrão na linha de cima"
    puts ""
    puts "show_locations_instruction_type: vai procurar todas as instruções Ruby \n       e mostrar seu ID e a localização"
    puts ""
    puts "show_locations_without_classifications: vai procurar todas as instruções \n       Ruby sem classificação e mostrar seu ID e a localização"
    puts ""
    puts "show_classes: vai procurar todos os comentário Ruby e sumarizar"
  end


  #método para definir a identação do comentário a ser colocado em cima de uma linha
  def indentation(line)
    if line.start_with?(" ")
      numbers_of_spaces = 1
      while line.start_with?(" "*numbers_of_spaces)
        numbers_of_spaces += 1
      end
      return " " * (numbers_of_spaces - 1)
    else
      return ""
    end
  end

  def define_argumentos(comandos)
    instrucoes_suportadas = ["send", "const_get", "const_set", "define_method", "instance_eval", "instance_exec", "eval"]
    comandos_suportados = ["setup", "show_locations", "show_locations_without_classification", "show_classifications", "export", "change_classification"]
    argumentos = {}
    argumentos[:comando] = nil
    argumentos[:args] = []
    argumentos[:analyse] = false
    comandos.each do |comando|
      if comandos_suportados.include? comando
        argumentos[:comando] = comando
      elsif comando == "analyse"
        argumentos[:analyse] = true
      else
        argumentos[:args] << comando
      end
    end
    return argumentos
  end

  private :get_classification, :get_instruction, :get_ID, :hash_ocorrencias,
          :setup, :show_location_without_classification, :show_location,
          :build_catalogo, :create_catalogo, :show_help, :indentation, :define_argumentos
end

files_to_research = Array.new

#activeadmin
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/activeadmin/**/lib/**/*.rb"

#diaspora
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/diaspora/**/lib/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/diaspora/app/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/diaspora/config/**/*.rb"

#discourse
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/discourse/**/lib/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/discourse/app/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/discourse/config/**/*.rb"

#gitlab
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/gitlabhq/**/lib/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/gitlabhq/app/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/gitlabhq/config/**/*.rb"

#homebrew
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/homebrew/**/lib/**/*.rb"

#paperclip
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/paperclip/**/lib/**/*.rb"

#rails
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/rails/**/lib/**/*.rb"

#rails_admin
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/rails_admin/**/lib/**/*.rb"

#ruby
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/ruby/**/lib/**/*.rb"

#spree
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/spree/**/lib/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/spree/api/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/spree/backend/**/*.rb"
files_to_research << "/home/elder/Documentos/IC/projetos_analisados/spree/core/**/*.rb"

nodyna = Nodyna.new
nodyna.option(files_to_research, ARGV)
