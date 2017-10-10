module Gitlab
  module Identifier
    def identify(identifier, project, newrev)
      if identifier.blank?
        email = project.commit(newrev).author_email rescue nil
        User.find_by(email: email) if email

      elsif identifier =~ /\Auser-\d+\Z/
        user_id = identifier.gsub("user-", "")
        User.find_by(id: user_id)

      elsif identifier =~ /\Akey-\d+\Z/
        key_id = identifier.gsub("key-", "")
        Key.find_by(id: key_id).try(:user)
      end
    end
  end
end
