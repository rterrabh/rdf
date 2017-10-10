if Gem.loaded_specs['rspec-activemodel-mocks'].version.to_s != "1.0.1"
  raise "RSpec-ActiveModel-Mocks version has changed, please check if the behaviour has already been fixed: https://github.com/rspec/rspec-activemodel-mocks/pull/10
If so, this patch might be obsolete-"
end
#nodyna <class_eval-2489> <not yet classified>
RSpec::ActiveModel::Mocks::Mocks::ActiveRecordInstanceMethods.class_eval do
  alias_method :_read_attribute, :[]
end
