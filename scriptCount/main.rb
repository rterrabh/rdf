require_relative 'StatementsCounter'
require_relative '../util/Util'
projects = {
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
  "Cancan": ["../../datasets_old/cancan/**/lib/**/*.rb"],
  "Capistrano": ["../../datasets_old/capistrano/**/lib/**/*.rb"],
  "Capybara": ["../../datasets_old/capybara/**/lib/**/*.rb"],
  "Carrierwave": ["../../datasets_old/carrierwave/**/lib/**/*.rb"],
  "CocoaPods": ["../../datasets_old/cocoaPods/**/lib/**/*.rb"],
  "Devdocs": ["../../datasets_old/devdocs/**/lib/**/*.rb"],
  "Devise": ["../../datasets_old/devise/**/lib/**/*.rb", "../../datasets_old/devise/**/app/**/*.rb"],
  "FPM": ["../../datasets_old/fpm/**/lib/**/*.rb"],
  "Grape": ["../../datasets_old/grape/**/lib/**/*.rb"],
  "Homebrew-Cask": ["../../datasets_old/homebrew-cask/**/lib/**/*.rb"],
  "Huginn": ["../../datasets_old/huginn/**/lib/**/*.rb", "../../datasets_old/huginn/**/app/**/*.rb"],
  "Jekyll": ["../../datasets_old/jekyll/**/lib/**/*.rb"],
  "Octopress": ["../../datasets_old/octopress/**/plugins/**/*.rb"],
  "Resque": ["../../datasets_old/resque/**/lib/**/*.rb"],
  "Sass": ["../../datasets_old/sass/**/lib/**/*.rb"],
  "Simple Form": ["../../datasets_old/simple_form/**/lib/**/*.rb"],
  "Vagrant": ["../../datasets_old/vagrant/**/lib/**/*.rb"],
  "Whenever": ["../../datasets_old/whenever/**/lib/**/*.rb"],
  
}

statements = 0
dynamicStatements = 0
projects.each do |projectName, dirs|
  puts "#{projectName}"
  totalStatements, totalDynamicStatements, percMethodsUsingDynamic, dynamicStatementsCounter = StatementsCounter.instance.count(Util.extractFiles(dirs))
  puts "Total Statements: #{totalStatements}"
  puts "Total Dynamic Statements: #{totalDynamicStatements}"
  puts "Methods using dynamic features: #{percMethodsUsingDynamic}%"
  dynamicStatementsCounter.each do |statement, value|
    puts "#{statement}: #{value}"
  end
  puts "##########"
  statements += totalStatements
  dynamicStatements += totalDynamicStatements
end
puts "Total statements: #{statements}"
puts "Total Dynamic Statements: #{dynamicStatements}"

