unless defined?(::JSON::JSON_LOADED) and ::JSON::JSON_LOADED
  require 'json'
end

class Regexp

  def self.json_create(object)
    new(object['s'], object['o'])
  end

  def as_json(*)
    {
      JSON.create_id => self.class.name,
      'o'            => options,
      's'            => source,
    }
  end

  def to_json(*)
    as_json.to_json
  end
end
