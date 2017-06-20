require_relative 'modules/RdfModules'

class Rdf
  include RdfModules

  def execute(files_to_research, commands)
    files = Array.new
    files_to_research.each do |rbfiles|
      files  += Dir.glob(rbfiles)
    end
    files.flatten!
    puts "Total files: #{files.size}"
    puts "#{"="*34} RDF OUTPUT #{"="*34}"

    arguments = defineArguments(commands)
    if arguments[:command].nil?
      showHelp
    elsif arguments[:command] == "setup"
      setup(files)
    elsif arguments[:command] == "show_classifications"
      buildCatalog(files)
    elsif arguments[:command] == "show_locations_without_classification"
      statement = arguments[:args].size > 0 ? arguments[:args][0] : nil
      showLocationsWithoutClassification(files, statement)
    elsif arguments[:command] == "show_locations"
      statement = arguments[:args].size > 0 ? arguments[:args][0] : nil
      classification = arguments[:args].size > 1 ? arguments[:args][1] : nil
      showLocations(files, statement, classification)
    end
    puts "#{"="*37} END #{"="*38}"
  end

  def showHelp
    puts "Help:"
    puts "setup: Put a default mark after every dynamic statement in the project to indicate that the statement have still not been classified"
    puts ""
    puts "show_locations <statement>: List the files where this statement type has already been marked"
    puts ""
    puts "show_locations_without_classifications: List the files where this statement type has already been marked, but has still not been classified"
    puts ""
    puts "show_classificatons: Summarizes the number of statements by each classification"
  end

  def defineArguments(commands)
    validStatements = ["send", "const_get", "const_set", "define_method", "instance_eval", "instance_exec", "eval"]
    validCommands = ["setup", "show_locations", "show_locations_without_classification", "show_classifications"]
    arguments = {}
    arguments[:command] = nil
    arguments[:args] = []
    if(commands.size > 0)
      if(validCommands.include?(commands[0]))
        arguments[:command] = commands[0]
      end
      index = 0
      commands.each do |command|
        if(index == 0)
          index += 1
          next
        end
        arguments[:args] << command
        index += 1
      end
    end
    return arguments
  end
	
end

files_to_research = Array.new

#activeadmin
files_to_research << "../dataset/activeadmin/**/lib/**/*.rb"

#diaspora
files_to_research << "../dataset/diaspora/**/lib/**/*.rb"
files_to_research << "../dataset/diaspora/app/**/*.rb"
files_to_research << "../dataset/diaspora/config/**/*.rb"

#discourse
files_to_research << "../dataset/discourse/**/lib/**/*.rb"
files_to_research << "../dataset/discourse/app/**/*.rb"
files_to_research << "../dataset/discourse/config/**/*.rb"

#gitlab
files_to_research << "../dataset/gitlabhq/**/lib/**/*.rb"
files_to_research << "../dataset/gitlabhq/app/**/*.rb"
files_to_research << "../dataset/gitlabhq/config/**/*.rb"

#homebrew
files_to_research << "../dataset/homebrew/**/lib/**/*.rb"

#paperclip
files_to_research << "../dataset/paperclip/**/lib/**/*.rb"

#rails
files_to_research << "../dataset/rails/**/lib/**/*.rb"

#rails_admin
files_to_research << "../dataset/rails_admin/**/lib/**/*.rb"

#ruby
files_to_research << "../dataset/ruby/**/lib/**/*.rb"

#spree
files_to_research << "../dataset/spree/**/lib/**/*.rb"
files_to_research << "../dataset/spree/api/**/*.rb"
files_to_research << "../dataset/spree/backend/**/*.rb"
files_to_research << "../dataset/spree/core/**/*.rb"

rdf = Rdf.new
rdf.execute(files_to_research, ARGV)
