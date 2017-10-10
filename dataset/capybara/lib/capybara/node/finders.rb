module Capybara
  module Node
    module Finders

      def find(*args)
        query = Capybara::Query.new(*args)
        synchronize(query.wait) do
          if query.match == :smart or query.match == :prefer_exact
            result = query.resolve_for(self, true)
            result = query.resolve_for(self, false) if result.size == 0 && !query.exact?
          else
            result = query.resolve_for(self)
          end
          if query.match == :one or query.match == :smart and result.size > 1
            raise Capybara::Ambiguous.new("Ambiguous match, found #{result.size} elements matching #{query.description}")
          end
          if result.size == 0
            raise Capybara::ElementNotFound.new("Unable to find #{query.description}")
          end
          result.first
        end.tap(&:allow_reload!)
      end

      def find_field(locator, options={})
        find(:field, locator, options)
      end
      alias_method :field_labeled, :find_field

      def find_link(locator, options={})
        find(:link, locator, options)
      end


      def find_button(locator, options={})
        find(:button, locator, options)
      end

      def find_by_id(id, options={})
        find(:id, id, options)
      end

      def all(*args)
        query = Capybara::Query.new(*args)
        synchronize(query.wait) do
          result = query.resolve_for(self)
          raise Capybara::ExpectationNotMet, result.failure_message unless result.matches_count?
          result
        end
      end
      alias_method :find_all, :all

      def first(*args)
        if Capybara.wait_on_first_by_default
          options = if args.last.is_a?(Hash) then args.pop.dup else {} end
          args.push({minimum: 1}.merge(options))
        end
        all(*args).first
      rescue Capybara::ExpectationNotMet
        nil
      end
    end
  end
end
