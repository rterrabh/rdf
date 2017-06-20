require_relative '../catalog/Catalog'
require_relative '../checker/Checker'

module RdfModules

  def getID(line)
    substring = line.match(/<([^>]*)> <([^>]*)>/)
    substring[1]
  end

  def getStatement(line)
    id = getID(line)
    str1_markerstring = ":"
    str2_markerstring = "-"
    id[/#{str1_markerstring}(.*?)#{str2_markerstring}/m, 1]
  end

  def getClassification(line)
    substring = line.match(/<([^>]*)> <([^>]*)>/)
    substring[2]
  end

  module ShowClassifications
    def initializeCatalog()
      catalog =  Catalog.new
      catalog.addItem("const_get")
      catalog.addItem("const_set")
      catalog.addItem("eval")
      catalog.addItem("define_method")
      catalog.addItem("instance_eval")
      catalog.addItem("instance_exec")
      catalog.addItem("send")
      return catalog
    end

    def buildCatalog(rbfiles)
      catalog = initializeCatalog
      rbfiles.each do |rbfile|
        File.open(rbfile, 'r').each do |line|
          if line.include? "#nodyna"
            instruction = getStatement(line)
            classification = getClassification(line)
            catalog.increaseClassification(instruction, classification)
          end
        end
      end
      catalog.showCatalog
    end
  end

  module ShowLocations

    def showLocations(rbfiles, statement, classification)
      total = 0
      rbfiles.each do |rbfile|
        number = 0
        File.open(rbfile, 'r').each do |line|
          number += 1
          if line.include? "#nodyna"
            if statement and classification
              if getStatement(line) == statement and getClassification(line) == classification
                puts "#{rbfile}.#{number}.#{getClassification(line)}.#{getID(line)}"
                total += 1
              end
            elsif statement
              if getStatement(line) == statement
                puts "#{rbfile}.#{number}.#{getClassification(line)}.#{getID(line)}"
                total += 1
              end
            elsif classification
              if getClassification(line) == classification
                puts "#{rbfile}.#{number}.#{getClassification(line)}.#{getID(line)}"
                total += 1
              end
            end
          end
        end
      end
      puts "Total: #{total}"
    end

    def showLocationsWithoutClassification(rbfiles, statement)
      showLocations(rbfiles, statement, "not yet classified")
    end
  end

  module Setup

    def initializeStatements
      statements = Hash.new
      statements[:send] = 0
      statements[:const_get] = 0
      statements[:const_set] = 0
      statements[:define_method] = 0
      statements[:instance_eval] = 0
      statements[:instance_exec] = 0
      statements[:eval] = 0
      return  statements
    end

    def setup(rbfiles)
      statements = initializeStatements
      rbfiles.each do |rbfile|
        newFile = ""
        saveFile = true
        File.open(rbfile, 'r').each do |line|
          if line.lstrip[0] != "#"
            statements.each do |statement, times|
              qtdEncontrada = Checker.hasStatement?(statement, line)
              for i in 1..qtdEncontrada
                statements[statement] += 1
                newFile = "#{newFile}#{indentation(line)}#nodyna <ID:#{statement}-#{statements[statement]}> <not yet classified>\n"
              end
            end
          elsif line.include? "nodyna"
            saveFile = false
            break
          end
          newFile = "#{newFile}#{line}"
        end
        if saveFile
          fh = File.open(rbfile, 'w')
          fh.puts newFile
          fh.close
        end
      end
    end

    def indentation(line)
      if line.start_with?(" ")
        numbersOfSpaces = 1
        while line.start_with?(" "*numbersOfSpaces)
          numbersOfSpaces += 1
        end
        return " " * (numbersOfSpaces - 1)
      else
        return ""
      end
    end
  end

  include ShowClassifications
  include ShowLocations
  include Setup
end
