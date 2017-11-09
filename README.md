# Rdf
Rdf (Ruby Dynamic Features Analysis Tool) is a tool to mark every dynamic statement (send, instance_exec, instance_eval, eval, define_method, const_get, and const_set) in the Ruby files. This helps developers to see where they are using the dynamic statements. Furthermore, the tool also allows developers to classificate the use of dyanamic statements.

## Functionalities
Rdf has the following functionalities:
- `./rdf setup`: Put a default mark after every dynamic statement in the project to indicate that the instructions have still not been classified. The default marking is: #rdf <ID - <instruction type>> < not yet classified >

- `./rdf show_locations instruction_type <classification_filter>`: List the files where this instruction type has already been marked.

- `./rdf show_locations_without_classification instruction_type`: List the files where this instruction type has already been marked, but has still not been classified.

- `./rdf show_classifications`: Summarizes the number of statements by each classification.

## How to use
Import Rdf for your project (`require_relative rdf`) and then use the command `Rdf.new.execute(files_to_analyze, option)` to execute Rdf, where **files_to_analyze** is a array that contains all pathes of Ruby files that you want to analyze and **option** is a Array that contains the commands to be executed (show_locations and the instruction type, show_classifications, etc).

## Statements counter
The folder script counter contains a basic statements (variable declaration, for, if, etc) and dynamic statements (attr_reader, method_missing, send, eval, etc.) counter. To run the script it is necessary import the class StatementsCounter (`require_relative StatementsCounter`) and then call the function StatementCounter.instance.count(**files**), where files is a list that contains the path of the files to checker.

## Dependencies
The statements counter uses the followings libraries:
- [ruby_parser](https://github.com/seattlerb/ruby_parser), install it using the command `sudo gem install ruby_parser`
- [sexp_processor](https://github.com/seattlerb/sexp_processor), intall it using the command `sudo gem install sexp_processor`

## Dataset
Rdf was used to analyze the dynamic statements of the following Ruby projects:
- [Active Admin](https://github.com/rterrabh/rdf/tree/master/dataset/activeadmin)
- [CanCan](https://github.com/rterrabh/rdf/tree/master/dataset/cancan)
- [Capistrano](https://github.com/rterrabh/rdf/tree/master/dataset/capistrano)
- [Capybara](https://github.com/rterrabh/rdf/tree/master/dataset/capybara)
- [Carrierwave](https://github.com/rterrabh/rdf/tree/master/dataset/carrierwave)
- [CocoaPods](https://github.com/rterrabh/rdf/tree/master/dataset/cocoaPods)
- [DevDocs](https://github.com/rterrabh/rdf/tree/master/dataset/devdocs)
- [devise](https://github.com/rterrabh/rdf/tree/master/dataset/devise)
- [diaspora*](https://github.com/rterrabh/rdf/tree/master/dataset/diaspora)
- [Discourse](https://github.com/rterrabh/rdf/tree/master/dataset/discourse)
- [FPM](https://github.com/rterrabh/rdf/tree/master/dataset/fpm)
- [Gitlab](https://github.com/rterrabh/rdf/tree/master/dataset/gitlabhq)
- [Grape](https://github.com/rterrabh/rdf/tree/master/dataset/grape)
- [Homebrew](https://github.com/rterrabh/rdf/tree/master/dataset/homebrew)
- [Homebrew-Cask](https://github.com/rterrabh/rdf/tree/master/dataset/homebrew-cask)
- [Huginn](https://github.com/rterrabh/rdf/tree/master/dataset/huginn)
- [Jekyll](https://github.com/rterrabh/rdf/tree/master/dataset/jekyll)
- [Octopress](https://github.com/rterrabh/rdf/tree/master/dataset/octopress)
- [Paperclip](https://github.com/rterrabh/rdf/tree/master/dataset/paperclip)
- [Rails](https://github.com/rterrabh/rdf/tree/master/dataset/rails)
- [Rails Admin](https://github.com/rterrabh/rdf/tree/master/dataset/rails_admin)
- [Resque](https://github.com/rterrabh/rdf/tree/master/dataset/resque)
- [Ruby](https://github.com/rterrabh/rdf/tree/master/dataset/ruby)
- [Sass](https://github.com/rterrabh/rdf/tree/master/dataset/sass)
- [Simple Form](https://github.com/rterrabh/rdf/tree/master/dataset/simple_form)
- [Spree](https://github.com/rterrabh/rdf/tree/master/dataset/spree)
- [Vagrant](https://github.com/rterrabh/rdf/tree/master/dataset/vagrant)
- [Whenever](https://github.com/rterrabh/rdf/tree/master/dataset/whenever)

