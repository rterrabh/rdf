module Jekyll
  module External
    class << self

      def blessed_gems
        %w{
          jekyll-docs
          jekyll-import
        }
      end

      def require_if_present(names)
        Array(names).each do |name|
          begin
            require name
          rescue LoadError
            Jekyll.logger.debug "Couldn't load #{name}. Skipping."
            false
          end
        end
      end

      def require_with_graceful_fail(names)
        Array(names).each do |name|
          begin
            require name
          rescue LoadError => e
            Jekyll.logger.error "Dependency Error:", <<-MSG
Yikes! It looks like you don't have #{name} or one of its dependencies installed.
In order to use Jekyll as currently configured, you'll need to install this gem.

The full error message from Ruby is: '#{e.message}'

If you run into trouble, you can find helpful resources at http://jekyllrb.com/help/!
            MSG
            raise Jekyll::Errors::MissingDependencyException.new(name)
          end
        end
      end

    end
  end
end
