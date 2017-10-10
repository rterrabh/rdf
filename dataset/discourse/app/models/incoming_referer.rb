class IncomingReferer < ActiveRecord::Base
  belongs_to :incoming_domain

  def self.add!(opts)
    domain_id = opts[:incoming_domain_id]
    domain_id ||= opts[:incoming_domain].id
    path = opts[:path]

    current = find_by(path: path, incoming_domain_id: domain_id)
    return current if current

    begin
      current = create!(path: path, incoming_domain_id: domain_id)
    rescue ActiveRecord::RecordNotUnique
    end

    current || find_by(path: path, incoming_domain_id: domain_id)
  end
end

