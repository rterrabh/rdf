require_relative 'StatementsCounter'

def extractFiles(pathes)
  files = []
  pathes.each do |path|
    files += Dir.glob(path)
  end
  files.flatten!
  files
end


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
  "Spree": ["../dataset/spree/**/lib/**/*.rb", "../dataset/spree/api/**/*.rb", "../dataset/spree/backend/**/*.rb", "../dataset/spree/core/**/*.rb"]
}

statements = 0
dynamicStatements = 0
projects.each do |projectName, dirs|
  puts "#{projectName}"
  totalStatements, totalDynamicStatements, percMethodsUsingDynamic, dynamicStatementsCounter = StatementsCounter.instance.count(extractFiles(dirs))
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

