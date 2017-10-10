unless defined?(::JSON::JSON_LOADED) and ::JSON::JSON_LOADED
  require 'json'
end

class Struct

  def self.json_create(object)
    new(*object['v'])
  end

  def as_json(*)
    klass = self.class.name
    klass.to_s.empty? and raise JSON::JSONError, "Only named structs are supported!"
    {
      JSON.create_id => klass,
      'v'            => values,
    }
  end

  def to_json(*args)
    as_json.to_json(*args)
  end
end
