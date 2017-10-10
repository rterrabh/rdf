unless defined?(::JSON::JSON_LOADED) and ::JSON::JSON_LOADED
  require 'json'
end

class Exception

  def self.json_create(object)
    result = new(object['m'])
    result.set_backtrace object['b']
    result
  end

  def as_json(*)
    {
      JSON.create_id => self.class.name,
      'm'            => message,
      'b'            => backtrace,
    }
  end

  def to_json(*args)
    as_json.to_json(*args)
  end
end
