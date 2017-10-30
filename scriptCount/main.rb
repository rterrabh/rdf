require_relative 'StatementsCounter'
require_relative 'ProjectData'
require_relative '../util/Util'
projects = {
#  "Test": ["target.rb"],
  "Active Admin": ["../dataset/activeadmin/**/lib/**/*.rb"],
  "Diaspora": ["../dataset/diaspora/**/lib/**/*.rb", "../dataset/diaspora/app/**/*.rb", "../dataset/diaspora/config/**/*.rb"],
  "Discourse": ["../dataset/discourse/**/lib/**/*.rb", "../dataset/discourse/app/**/*.rb", "../dataset/discourse/config/**/*.rb"],
  "GitLab": ["../dataset/gitlabhq/**/lib/**/*.rb", "../dataset/gitlabhq/app/**/*.rb", "../dataset/gitlabhq/config/**/*.rb"],
  "Homebrew": ["../dataset/homebrew/**/lib/**/*.rb"],
  "Paperclip": ["../dataset/paperclip/**/lib/**/*.rb"],
  "Rails": ["../dataset/rails/**/lib/**/*.rb"],
  "Rails Admin": ["../dataset/rails_admin/**/lib/**/*.rb"],
  "Ruby": ["../dataset/ruby/**/lib/**/*.rb"],
  "Spree": ["../dataset/spree/**/lib/**/*.rb", "../dataset/spree/api/**/*.rb", "../dataset/spree/backend/**/*.rb", "../dataset/spree/core/**/*.rb"],
  "Cancan": ["../dataset/cancan/**/lib/**/*.rb"],
  "Capistrano": ["../dataset/capistrano/**/lib/**/*.rb"],
  "Capybara": ["../dataset/capybara/**/lib/**/*.rb"],
  "Carrierwave": ["../dataset/carrierwave/**/lib/**/*.rb"],
  "CocoaPods": ["../dataset/cocoaPods/**/lib/**/*.rb"],
  "Devdocs": ["../dataset/devdocs/**/lib/**/*.rb"],
  "Devise": ["../dataset/devise/**/lib/**/*.rb", "../dataset/devise/**/app/**/*.rb"],
  "FPM": ["../dataset/fpm/**/lib/**/*.rb"],
  "Grape": ["../dataset/grape/**/lib/**/*.rb"],
  "Homebrew-Cask": ["../dataset/homebrew-cask/**/lib/**/*.rb"],
  "Huginn": ["../dataset/huginn/**/lib/**/*.rb", "../dataset/huginn/**/app/**/*.rb"],
  "Jekyll": ["../dataset/jekyll/**/lib/**/*.rb"],
  "Octopress": ["../dataset/octopress/**/plugins/**/*.rb"],
  "Resque": ["../dataset/resque/**/lib/**/*.rb"],
  "Sass": ["../dataset/sass/**/lib/**/*.rb"],
  "Simple Form": ["../dataset/simple_form/**/lib/**/*.rb"],
  "Vagrant": ["../dataset/vagrant/**/lib/**/*.rb"],
  "Whenever": ["../dataset/whenever/**/lib/**/*.rb"]
}

general = ProjectData.new
projects.each do |projectName, dirs|
  puts "#{"=" * 25}"
  puts "#{projectName}"
  puts "#{"=" * 25}"
  files = Util.extractFiles(dirs)
  projectData = StatementsCounter.instance.count(files)
  projectData.print
  general.totalStatements += projectData.totalStatements
  general.totalDynamicStatements += projectData.totalDynamicStatements
  general.loc += projectData.loc
  general.locDynamic += projectData.locDynamic
  general.totalClasses += projectData.totalClasses
  general.totalClassesWithMethodMissing += projectData.totalClassesWithMethodMissing
  general.totalMethods += projectData.totalMethods
  general.totalMethodsUsingDynamic += projectData.totalMethodsUsingDynamic
  projectData.dynamicStatements.each do |dynamicStatement, occurences|
    if(!general.dynamicStatements.has_key?(dynamicStatement))
      general.dynamicStatements[dynamicStatement] = 0
    end
    general.dynamicStatements[dynamicStatement] += occurences
  end
end
puts "#{"=" * 25}"
puts "General"
puts "#{"=" * 25}"
puts general.print

