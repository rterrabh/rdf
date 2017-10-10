class IncomingDomain < ActiveRecord::Base
  def self.add!(uri)
    name = uri.host
    https = uri.scheme == "https"
    port = uri.port

    current = find_by(name: name, https: https, port: port)
    return current if current


    begin
      current = create!(name: name, https: https, port: port)
    rescue ActiveRecord::RecordNotUnique
    end

    current || find_by(name: name, https: https, port: port)
  end

  def to_url
    url = "http#{https ? "s" : ""}://#{name}"

    if https && port != 443 || !https && port != 80
      url << ":#{port}"
    end

    url
  end
end

