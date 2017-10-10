class AvatarLookup

  def initialize(user_ids=[])
    @user_ids = user_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  def [](user_id)
    users[user_id]
  end

  private

  def self.lookup_columns
    @lookup_columns ||= [:id,
                         :email,
                         :username,
                         :uploaded_avatar_id]
  end

  def users
    @users ||= user_lookup_hash
  end

  def user_lookup_hash
    hash = {}
    User.where(:id => @user_ids)
        .select(AvatarLookup.lookup_columns)
        .each{ |user| hash[user.id] = user }
    hash
  end
end
