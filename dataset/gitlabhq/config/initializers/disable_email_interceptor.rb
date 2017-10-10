ActionMailer::Base.register_interceptor(DisableEmailInterceptor) unless Gitlab.config.gitlab.email_enabled
