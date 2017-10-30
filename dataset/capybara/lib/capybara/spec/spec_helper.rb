require "rspec"
require "capybara"
require "capybara/rspec" # Required here instead of in rspec_spec to avoid RSpec deprecation warning
require "capybara/spec/test_app"
require "nokogiri"

unless RSpec::Matchers.method_defined?(:be_truthy)
  #nodyna <module_eval-2648> <ME MODERATE (block execution)>
  RSpec::Matchers.module_eval do
    alias be_truthy be_true
    alias be_falsey be_false
    alias be_falsy be_false
  end
end

module Capybara
  module SpecHelper
    class << self
      def configure(config)
        config.filter_run_excluding :requires => method(:filter).to_proc
        config.before { Capybara::SpecHelper.reset! }
        config.after { Capybara::SpecHelper.reset! }
      end

      def reset!
        Capybara.app = TestApp
        Capybara.app_host = nil
        Capybara.default_selector = :xpath
        Capybara.default_max_wait_time = 1
        Capybara.ignore_hidden_elements = true
        Capybara.exact = false
        Capybara.exact_options = false
        Capybara.raise_server_errors = true
        Capybara.visible_text_only = false
        Capybara.match = :smart
        Capybara.wait_on_first_by_default = false
      end

      def filter(requires, metadata)
        if requires and metadata[:capybara_skip]
          requires.any? do |require|
            metadata[:capybara_skip].include?(require)
          end
        else
          false
        end
      end

      def spec(name, options={}, &block)
        @specs ||= []
        @specs << [name, options, block]
      end

      def run_specs(session, name, options={})
        specs = @specs
        RSpec.describe Capybara::Session, name, options do
          include Capybara::SpecHelper
          include Capybara::RSpecMatchers
          before do
            @session = session
          end
          after do
            @session.reset_session!
          end
          specs.each do |spec_name, spec_options, block|
            describe spec_name, spec_options do
              #nodyna <class_eval-2649> <CE COMPLEX (block execution)>
              class_eval(&block)
            end
          end
        end
      end
    end # class << self

    def silence_stream(stream)
      old_stream = stream.dup
      stream.reopen(RbConfig::CONFIG['host_os'] =~ /rmswin|mingw/ ? 'NUL:' : '/dev/null')
      stream.sync = true
      yield
    ensure
      stream.reopen(old_stream)
    end

    def quietly
      silence_stream(STDOUT) do
        silence_stream(STDERR) do
          yield
        end
      end
    end

    def extract_results(session)
      expect(session).to have_xpath("//pre[@id='results']")
      YAML.load Nokogiri::HTML(session.body).xpath("//pre[@id='results']").first.inner_html.lstrip
    end
  end
end

Dir[File.dirname(__FILE__) + "/session/**/*.rb"].each { |file| require_relative file }
