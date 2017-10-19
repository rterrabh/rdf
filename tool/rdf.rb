require_relative 'modules/RdfModules'
require_relative '../util/Util'
class Rdf
  include RdfModules

  def execute(files_to_research, arguments)
    files = Util.extractFiles(files_to_research)
    puts "#{"="*34} RDF OUTPUT #{"="*34}"
    if(arguments.nil? || arguments.size == 0)
      showHelp()
    elsif(arguments[0] == "setup")
      puts "Total files: #{files.size}"
      setup(files)
    elsif(arguments[0] == "show_classifications")
      puts "Total files: #{files.size}"
      buildCatalog(files).showCatalog
    elsif(arguments.size >= 2 && arguments[0] == "show_locations")
      puts "Total files: #{files.size}"
      statement = arguments[1]
      classification = arguments.size >= 3 ? arguments[2] : nil
      showLocations(files, statement, classification)
    elsif(arguments[0] == "show_locations_without_classification")
      puts "Total files: #{files.size}"
      statement = arguments.size >= 1 ? arguments[1] : nil
      showLocationsWithoutClassification(files, statement)
    elsif(arguments.size >= 3 && arguments[0] == "change_classification")
      puts "Total files: #{files.size}"
      oldClassification = arguments[1]
      newClassification = arguments[2]
      changeClassification(files, oldClassification, newClassification)
    else
      showHelp()
    end
    puts "#{"="*37} END #{"="*38}"
  end

  def showHelp
    puts "Help:"
    puts "setup: Put a default mark after every dynamic statement in the project to indicate that the statement have still not been classified"
    puts ""
    puts "show_locations statement <classification>: List the files where this statement type has already been marked"
    puts ""
    puts "show_locations_without_classifications <statement>: List the files where this statement type has already been marked, but has still not been classified"
    puts ""
    puts "show_classificatons: Summarizes the number of statements by each classification"
  end	
end

files_to_research = []


#activeadmin
files_to_research << "../dataset/activeadmin/**/lib/**/*.rb"

#diaspora
#files_to_research << "../dataset/diaspora/**/lib/**/*.rb"
#files_to_research << "../dataset/diaspora/app/**/*.rb"
#files_to_research << "../dataset/diaspora/config/**/*.rb"

#discourse
#files_to_research << "../dataset/discourse/**/lib/**/*.rb"
#files_to_research << "../dataset/discourse/app/**/*.rb"
#files_to_research << "../dataset/discourse/config/**/*.rb"

#gitlab
#files_to_research << "../dataset/gitlabhq/**/lib/**/*.rb"
#files_to_research << "../dataset/gitlabhq/app/**/*.rb"
#files_to_research << "../dataset/gitlabhq/config/**/*.rb"

#homebrew
#files_to_research << "../dataset/homebrew/**/lib/**/*.rb"

#paperclip
#files_to_research << "../dataset/paperclip/**/lib/**/*.rb"

#rails
#files_to_research << "../dataset/rails/**/lib/**/*.rb"

#rails_admin
#files_to_research << "../dataset/rails_admin/**/lib/**/*.rb"

#ruby
#files_to_research << "../dataset/ruby/**/lib/**/*.rb"

#spree
#files_to_research << "../dataset/spree/**/lib/**/*.rb"
#files_to_research << "../dataset/spree/api/**/*.rb"
#files_to_research << "../dataset/spree/backend/**/*.rb"
#files_to_research << "../dataset/spree/core/**/*.rb"

#cancan
#files_to_research << "../dataset/cancan/**/lib/**/*.rb"

#capistrano
#files_to_research << "../dataset/capistrano/**/lib/**/*.rb"

#capybara
#files_to_research << "../dataset/capybara/**/lib/**/*.rb"

#carrierwave
#files_to_research << "../dataset/carrierwave/**/lib/**/*.rb"

#cocoapods
#files_to_research << "../dataset/cocoaPods/**/lib/**/*.rb"

#devdocs
#files_to_research << "../dataset/devdocs/**/lib/**/*.rb"

#devise
#files_to_research << "../dataset/devise/**/lib/**/*.rb"
#files_to_research << "../dataset/devise/**/app/**/*.rb"

#fpm
#files_to_research << "../dataset/fpm/**/lib/**/*.rb"

#grape
#files_to_research << "../dataset/grape/**/lib/**/*.rb"

#homebrew-cask
#files_to_research << "../dataset/homebrew-cask/**/lib/**/*.rb"

#huginn
#files_to_research << "../dataset/huginn/**/lib/**/*.rb"
#files_to_research << "../dataset/huginn/**/app/**/*.rb"

#jekyll
#files_to_research << "../dataset/jekyll/**/lib/**/*.rb"

#octopress
#files_to_research << "../dataset/octopress/**/plugins/**/*.rb"

#resque
#files_to_research << "../dataset/resque/**/lib/**/*.rb"

#sass
#files_to_research << "../dataset/sass/**/lib/**/*.rb"

#simple form
#files_to_research << "../dataset/simple_form/**/lib/**/*.rb"

#vagrant
#files_to_research << "../dataset/vagrant/**/lib/**/*.rb"

#whenever
#files_to_research << "../dataset/whenever/**/lib/**/*.rb"

rdf = Rdf.new
rdf.execute(files_to_research, ARGV)
