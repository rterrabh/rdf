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
    def buildCatalog(rbfiles)
      catalog = Catalog.new
      rbfiles.each do |rbfile|
        File.open(rbfile, 'r').each do |line|
          if line.include? "#nodyna"
            instruction = getStatement(line)
            classification = getClassification(line)
            catalog.increaseClassification(instruction, classification)
          end
        end
      end
      return catalog
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

    def setup(rbfiles)
      skipStatements = Checker.createDynamicCounter()
      id = 1
      rbfiles.each do |rbfile|
        newFile = ""
        File.open(rbfile, 'r').each do |line|
          if line.lstrip[0] != "#"
            occurences = Checker.getOccurences(line)
            occurences.each do |statement, occurence|
              for i in 1..occurence
                if(skipStatements[statement] == 0)
                  newFile = "#{newFile}#{indentation(line)}#nodyna <ID:#{statement}-#{id}> <not yet classified>\n"
                  id += 1
                else
                  skipStatements[statement] -= 1
                end
              end
            end
            newFile = "#{newFile}#{line}"
          elsif line.include? "nodyna"
            statement = getStatement(line)
            classification = getClassification(line)
            skipStatements[statement.to_sym] += 1
            newFile = "#{newFile}#{indentation(line)}#nodyna <ID:#{statement}-#{id}> <#{classification}>\n"
            id += 1
          end
        end
        fh = File.open(rbfile, 'w')
        fh.puts newFile
        fh.close
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
