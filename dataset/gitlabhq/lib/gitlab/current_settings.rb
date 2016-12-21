module Gitlab
  module CurrentSettings
    def current_application_settings
      key = :current_application_settings

      RequestStore.store[key] ||= begin
        if ActiveRecord::Base.connected? && ActiveRecord::Base.connection.table_exists?('application_settings')
          ApplicationSetting.current || ApplicationSetting.create_from_defaults
        else
          fake_application_settings
        end
      end
    end

    def fake_application_settings
      OpenStruct.new(
        default_projects_limit: Settings.gitlab['default_projects_limit'],
        default_branch_protection: Settings.gitlab['default_branch_protection'],
        signup_enabled: Settings.gitlab['signup_enabled'],
        signin_enabled: Settings.gitlab['signin_enabled'],
        gravatar_enabled: Settings.gravatar['enabled'],
        sign_in_text: Settings.extra['sign_in_text'],
        restricted_visibility_levels: Settings.gitlab['restricted_visibility_levels'],
        max_attachment_size: Settings.gitlab['max_attachment_size'],
        session_expire_delay: Settings.gitlab['session_expire_delay']
      )
    end
  end
end
