
require 'webrick/httpservlet/abstract'
require 'webrick/httpservlet/filehandler'
require 'webrick/httpservlet/cgihandler'
require 'webrick/httpservlet/erbhandler'
require 'webrick/httpservlet/prochandler'

module WEBrick
  module HTTPServlet
    FileHandler.add_handler("cgi", CGIHandler)
    FileHandler.add_handler("rhtml", ERBHandler)
  end
end
