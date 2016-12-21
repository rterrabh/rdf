require File.join(File.dirname(__FILE__), "lib", "active_admin", "version")

Gem::Specification.new do |s|
  s.name          = 'activeadmin'
  s.license       = 'MIT'
  s.version       = ActiveAdmin::VERSION
  s.homepage      = 'http://activeadmin.info'
  s.authors       = ['Greg Bell']
  s.email         = ['gregdbell@gmail.com']
  s.description   = 'The administration framework for Ruby on Rails.'
  s.summary       = 'The administration framework for Ruby on Rails.'

  s.files         = `git ls-files`.split("\n").sort
  s.test_files    = `git ls-files -- {spec,features}/*`.split("\n")

  s.add_dependency 'arbre',               '~> 1.0', '>= 1.0.2'
  s.add_dependency 'bourbon'
  s.add_dependency 'coffee-rails'
  s.add_dependency 'formtastic',          '~> 3.1'
  s.add_dependency 'formtastic_i18n'
  s.add_dependency 'inherited_resources', '~> 1.6'
  s.add_dependency 'jquery-rails'
  s.add_dependency 'jquery-ui-rails',     '~> 5.0'
  s.add_dependency 'kaminari',            '~> 0.15'
  s.add_dependency 'rails',               '>= 3.2', '< 5.0'
  s.add_dependency 'ransack',             '~> 1.3'
  s.add_dependency 'sass-rails'
end
