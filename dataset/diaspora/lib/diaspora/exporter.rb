
module Diaspora

  class Exporter

    SERIALIZED_VERSION = '1.0'

    def initialize(user)
      @user = user
    end

    def execute
      @export ||= JSON.generate serialized_user.merge(version: SERIALIZED_VERSION)
    end

    private

    def serialized_user
      @serialized_user ||= Export::UserSerializer.new(@user).as_json
    end

  end

end
