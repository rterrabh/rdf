require_relative 'TotalStatementsChecker'

def extractFiles(pathes)
  files = []
  pathes.each do |path|
    files += Dir.glob(path)
  end
  files.flatten!
  files
end

total = 0
#activeadmin
files_to_research = []
puts "Active Admin"
files_to_research << "../dataset/activeadmin/**/lib/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#diaspora
files_to_research = []
puts "diaspora*"
files_to_research << "../dataset/diaspora/**/lib/**/*.rb"
files_to_research << "../dataset/diaspora/app/**/*.rb"
files_to_research << "../dataset/diaspora/config/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#discourse
files_to_research = []
puts "Discourse"
files_to_research << "../dataset/discourse/**/lib/**/*.rb"
files_to_research << "../dataset/discourse/app/**/*.rb"
files_to_research << "../dataset/discourse/config/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#gitlab
files_to_research = []
puts "Gitlab"
files_to_research << "../dataset/gitlabhq/**/lib/**/*.rb"
files_to_research << "../dataset/gitlabhq/app/**/*.rb"
files_to_research << "../dataset/gitlabhq/config/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#homebrew
files_to_research = []
puts "Homebrew"
files_to_research << "../dataset/homebrew/**/lib/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#paperclip
files_to_research = []
puts "Paperclip"
files_to_research << "../dataset/paperclip/**/lib/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#rails
files_to_research = []
puts "Rails"
files_to_research << "../dataset/rails/**/lib/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#rails_admin
files_to_research = []
puts "Rails Admin"
files_to_research << "../dataset/rails_admin/**/lib/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#ruby
files_to_research = []
puts "Ruby"
files_to_research << "../dataset/ruby/**/lib/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements

#spree
files_to_research = []
puts "Spree"
files_to_research << "../dataset/spree/**/lib/**/*.rb"
files_to_research << "../dataset/spree/api/**/*.rb"
files_to_research << "../dataset/spree/backend/**/*.rb"
files_to_research << "../dataset/spree/core/**/*.rb"
statements = TotalStatementsChecker.instance.checker(extractFiles(files_to_research))
puts "Total: #{statements}"
total += statements


puts "Total statements: #{total}"
