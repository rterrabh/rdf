unless defined?(::JSON::JSON_LOADED) and ::JSON::JSON_LOADED
  require 'json'
end

class Symbol
  def as_json(*)
    {
      JSON.create_id => self.class.name,
      's'            => to_s,
    }
  end

  def to_json(*a)
    as_json.to_json(*a)
  end

  def self.json_create(o)
    o['s'].to_sym
  end
end
