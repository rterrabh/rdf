module Gitlab
  module ShellEnv
    extend self

    def set_env(user)
      if user
        ENV['GL_ID'] = gl_id(user)
      end
    end

    def reset_env
      ENV['GL_ID'] = nil
    end

    def gl_id(user)
      if user.present?
        "user-#{user.id}"
      else
        ""
      end
    end
  end
end
