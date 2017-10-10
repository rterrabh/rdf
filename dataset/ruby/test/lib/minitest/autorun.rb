
begin
  require 'rubygems'
  gem 'minitest'
rescue Gem::LoadError
end

require 'minitest/unit'
require 'minitest/mock'

MiniTest::Unit.autorun
