if RSpec::Core::Version::STRING.to_f >= 3.0
  RSpec.shared_context "Capybara Features", :capybara_feature => true do
    #nodyna <instance_eval-2654> <not yet classified>
    instance_eval do
      alias background before
      alias given let
      alias given! let!
    end
  end

  RSpec.configure do |config|
    config.alias_example_group_to :feature, :capybara_feature => true, :type => :feature
    config.alias_example_to :scenario
    config.alias_example_to :xscenario, :skip => "Temporarily disabled with xscenario"
    config.alias_example_to :fscenario, :focus => true
  end
else
  module Capybara
    module Features
      def self.included(base)
        #nodyna <instance_eval-2655> <not yet classified>
        base.instance_eval do
          alias :background :before
          alias :scenario :it
          alias :xscenario :xit
          alias :given :let
          alias :given! :let!
          alias :feature :describe
        end
      end
    end
  end


  def self.feature(*args, &block)
    options = if args.last.is_a?(Hash) then args.pop else {} end
    options[:capybara_feature] = true
    options[:type] = :feature
    options[:caller] ||= caller
    args.push(options)

    RSpec.describe(*args, &block)
  end

  RSpec.configuration.include Capybara::Features, :capybara_feature => true
end
