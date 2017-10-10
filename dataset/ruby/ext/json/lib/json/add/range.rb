unless defined?(::JSON::JSON_LOADED) and ::JSON::JSON_LOADED
  require 'json'
end

class Range

  def self.json_create(object)
    new(*object['a'])
  end

  def as_json(*)
    {
      JSON.create_id  => self.class.name,
      'a'             => [ first, last, exclude_end? ]
    }
  end

  def to_json(*args)
    as_json.to_json(*args)
  end
end
