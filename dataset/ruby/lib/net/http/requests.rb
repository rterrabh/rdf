
class Net::HTTP::Get < Net::HTTPRequest
  METHOD = 'GET'
  REQUEST_HAS_BODY  = false
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Head < Net::HTTPRequest
  METHOD = 'HEAD'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = false
end

class Net::HTTP::Post < Net::HTTPRequest
  METHOD = 'POST'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Put < Net::HTTPRequest
  METHOD = 'PUT'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Delete < Net::HTTPRequest
  METHOD = 'DELETE'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Options < Net::HTTPRequest
  METHOD = 'OPTIONS'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Trace < Net::HTTPRequest
  METHOD = 'TRACE'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = true
end


class Net::HTTP::Patch < Net::HTTPRequest
  METHOD = 'PATCH'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end


class Net::HTTP::Propfind < Net::HTTPRequest
  METHOD = 'PROPFIND'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Proppatch < Net::HTTPRequest
  METHOD = 'PROPPATCH'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Mkcol < Net::HTTPRequest
  METHOD = 'MKCOL'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Copy < Net::HTTPRequest
  METHOD = 'COPY'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Move < Net::HTTPRequest
  METHOD = 'MOVE'
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Lock < Net::HTTPRequest
  METHOD = 'LOCK'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end

class Net::HTTP::Unlock < Net::HTTPRequest
  METHOD = 'UNLOCK'
  REQUEST_HAS_BODY = true
  RESPONSE_HAS_BODY = true
end

