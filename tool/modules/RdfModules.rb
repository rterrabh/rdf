require_relative '../catalog/Catalog'
require_relative '../checker/Checker'

module RdfModules


  def generateMark(idNumber, statement, classification)
    return "#nodyna <#{statement}-#{idNumber}> <#{classification}>"
  end

  def generateMarkWithFullyId(id, classification)
    return "#nodyna <#{id}> <#{classification}>"
  end

  def getID(line)
    return line.match(/<([^>]*)> <([^>]*)>/)[1]
  end

  def getStatement(line)
    id = getID(line)
    occurences = Checker.getOccurences(id)
    occurences.each do |dynamic_feature, occurence|
      if(occurence > 0)
        return dynamic_feature
      end
    end
    return nil
  end

  def getClassification(line)
    return line.match(/<([^>]*)> <([^>]*)>/)[2]
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
        absolutePath = File.absolute_path(rbfile)
        number = 0
        File.open(rbfile, 'r').each do |line|
          number += 1
          if line.include? "#nodyna"
            if statement and classification
              if getStatement(line) == statement.to_sym and getClassification(line) == classification
                puts "#{absolutePath}.#{number}.#{getClassification(line)}.#{getID(line)}"
                total += 1
              end
            elsif statement
              if getStatement(line) == statement.to_sym
                puts "#{absolutePath}.#{number}.#{getClassification(line)}.#{getID(line)}"
                total += 1
              end
            elsif classification
              if getClassification(line) == classification
                puts "#{absolutePath}.#{number}.#{getClassification(line)}.#{getID(line)}"
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


  module ChangeClassification

    def changeClassification(rbfiles, oldClassification, newClassification)
      rbfiles.each do |rbfile|
        newFile = ""
        File.open(rbfile, 'r').each do |line|
          if line.include? "#nodyna"
            classification = getClassification(line)
            id = getID(line)
            if(classification == oldClassification)
              newFile = "#{newFile}#{indentation(line)}#{generateMarkWithFullyId(id, newClassification)}\n"
            else
              newFile = "#{newFile}#{line}"
            end
          else
            newFile = "#{newFile}#{line}"
          end
        end
        fh = File.open(rbfile, 'w')
        fh.puts newFile
        fh.close
      end
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
                  newFile = "#{newFile}#{indentation(line)}#{generateMark(id, statement, "not yet classified")}\n"
                  id += 1
                else
                  skipStatements[statement] -= 1
                end
              end
            end
            newFile = "#{newFile}#{line}"
          elsif line.include? "nodyna"
            idClassification = getID(line)
            statement = getStatement(line)
            if(statement.nil?)
              statement = "?"
            else
              skipStatements[statement.to_sym] += 1
            end
            classification = getClassification(line)
            newFile = "#{newFile}#{indentation(line)}#{generateMark(id, statement, classification)}\n"
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
  include ChangeClassification
end
