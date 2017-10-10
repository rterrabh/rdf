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
  "Whenever": ["../dataset/whenever/**/lib/**/*.rb"],
  
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

