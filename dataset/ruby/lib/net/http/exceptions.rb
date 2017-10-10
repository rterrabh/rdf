module Net::HTTPExceptions
  def initialize(msg, res)   #:nodoc:
    super msg
    @response = res
  end
  attr_reader :response
  alias data response    #:nodoc: obsolete
end
class Net::HTTPError < Net::ProtocolError
  include Net::HTTPExceptions
end
class Net::HTTPRetriableError < Net::ProtoRetriableError
  include Net::HTTPExceptions
end
class Net::HTTPServerException < Net::ProtoServerError
  include Net::HTTPExceptions
end
class Net::HTTPFatalError < Net::ProtoFatalError
  include Net::HTTPExceptions
end

