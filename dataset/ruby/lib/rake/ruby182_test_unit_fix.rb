
module Test                     # :nodoc:
  module Unit                   # :nodoc:
    module Collector            # :nodoc:
      class Dir                 # :nodoc:
        undef collect_file
        def collect_file(name, suites, already_gathered) # :nodoc:
          dir = File.dirname(File.expand_path(name))
          $:.unshift(dir) unless $:.first == dir
          if @req
            @req.require(name)
          else
            require(name)
          end
          find_test_cases(already_gathered).each do |t|
            add_suite(suites, t.suite)
          end
        ensure
          $:.delete_at $:.rindex(dir)
        end
      end
    end
  end
end
