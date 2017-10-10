unless defined?(::JSON::JSON_LOADED) and ::JSON::JSON_LOADED
  require 'json'
end
require 'ostruct'

class OpenStruct

  def self.json_create(object)
    new(object['t'] || object[:t])
  end

  def as_json(*)
    klass = self.class.name
    klass.to_s.empty? and raise JSON::JSONError, "Only named structs are supported!"
    {
      JSON.create_id => klass,
      't'            => table,
    }
  end

  def to_json(*args)
    as_json.to_json(*args)
  end
end
