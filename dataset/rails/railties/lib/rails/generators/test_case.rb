require 'rails/generators'
require 'rails/generators/testing/behaviour'
require 'rails/generators/testing/setup_and_teardown'
require 'rails/generators/testing/assertions'
require 'fileutils'

module Rails
  module Generators
    no_color!

    class TestCase < ActiveSupport::TestCase
      include Rails::Generators::Testing::Behaviour
      include Rails::Generators::Testing::SetupAndTeardown
      include Rails::Generators::Testing::Assertions
      include FileUtils

    end
  end
end
