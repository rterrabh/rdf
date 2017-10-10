unless defined?(::JSON::JSON_LOADED) and ::JSON::JSON_LOADED
  require 'json'
end

class Time

  def self.json_create(object)
    if usec = object.delete('u') # used to be tv_usec -> tv_nsec
      object['n'] = usec * 1000
    end
    if instance_methods.include?(:tv_nsec)
      at(object['s'], Rational(object['n'], 1000))
    else
      at(object['s'], object['n'] / 1000)
    end
  end

  def as_json(*)
    nanoseconds = [ tv_usec * 1000 ]
    respond_to?(:tv_nsec) and nanoseconds << tv_nsec
    nanoseconds = nanoseconds.max
    {
      JSON.create_id => self.class.name,
      's'            => tv_sec,
      'n'            => nanoseconds,
    }
  end

  def to_json(*args)
    as_json.to_json(*args)
  end
end
