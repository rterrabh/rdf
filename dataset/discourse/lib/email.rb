require 'mail'
require_dependency 'email/message_builder'
require_dependency 'email/renderer'
require_dependency 'email/sender'
require_dependency 'email/styles'

module Email

  def self.is_valid?(email)

    return false unless String === email

    parser = Mail::RFC2822Parser.new
    parser.root = :addr_spec
    result = parser.parse(email)

    result && result.respond_to?(:domain) && result.domain.dot_atom_text.elements.size > 1
  end

  def self.downcase(email)
    return email unless Email.is_valid?(email)
    email.downcase
  end

  def self.cleanup_alias(name)
    name ? name.gsub(/[:<>,]/, '') : name
  end

end
