require 'rdoc'


module RDoc::RI


  class Error < RDoc::Error; end

  autoload :Driver, 'rdoc/ri/driver'
  autoload :Paths,  'rdoc/ri/paths'
  autoload :Store,  'rdoc/ri/store'

end

