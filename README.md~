# Nodyna
Nodyna is a tool to mark every dynamic statement (send, instance_exec, instance_eval, eval, define_method, const_get, and const_set) in the Ruby files. This helps developers to see where they are using the dynamic statements. Furthermore, the tool also allows developers to classificate the use of dyanamic statements.

## Dependencies
Nodyna use the followings libraries:
- [ruby_parser](https://github.com/seattlerb/ruby_parser), install it using the command `sudo gem install ruby_parser`
- [sexp_processor](https://github.com/seattlerb/sexp_processor), intall it using the command `sudo gem install sexp_processor`

## Functionalities
Nodyna has the following functionalities:
- `./nodyna setup`: Put a default mark after every dynamic statement in the project to indicate that the instructions have still not been classified. The default marking is: #nodyna <ID - <instruction type>> < not yet classified >

- `./nodyna show_locations <instruction type>`: List the files where this instruction type has already been marked.

- `./nodyna show_locations_without_classification <instruction type>`: List the files where this instruction type has already been marked, but has still not been classified.

- `./nodyna show_classifications`: Summarizes the number of statements by each classification.

## How to use
After installing all the dependencies, import nodyna for your project (`require_relative nodyna`) and then use the command `Nodyna.new.option(files_to_analyze, option)` to execute nodyna, where **files_to_analyze** is a array that contains all pathes of Ruby files that you want to analyze and **option** is a String that contains the command to be executed (show_locations, show_classifications, etc).

## Dataset
Nodyna was used to analyze the dynamic statements of the following Ruby projects:
- [Active Admin](https://github.com/rterrabh/nodyna/tree/master/dataset/activeadmin)
- [diaspora*](https://github.com/rterrabh/nodyna/tree/master/dataset/diaspora)
- [Discourse](https://github.com/rterrabh/nodyna/tree/master/dataset/discourse)
- [Gitlab](https://github.com/rterrabh/nodyna/tree/master/dataset/gitlabhq)
- [Homebrew](https://github.com/rterrabh/nodyna/tree/master/dataset/homebrew)
- [Paperclip](https://github.com/rterrabh/nodyna/tree/master/dataset/paperclip)
- [Rails](https://github.com/rterrabh/nodyna/tree/master/dataset/rails)
- [Rails Admin](https://github.com/rterrabh/nodyna/tree/master/dataset/rails_admin)
- [Ruby](https://github.com/rterrabh/nodyna/tree/master/dataset/ruby)
- [Spree](https://github.com/rterrabh/nodyna/tree/master/dataset/spree)

