Logging::Rails.configure do |config|
  Logging.init %w(debug info warn error fatal)

  Logging.format_as :inspect

  pattern = "[%d] %-5l PID-%p TID-%t %c: %m\n"
  layout = Logging.layouts.pattern(pattern: pattern)

  Logging.color_scheme("bright",
                       levels:  {
                         info:  :green,
                         warn:  :yellow,
                         error: :red,
                         fatal: %i(white on_red)
                       },
                       date:    :blue,
                       logger:  :cyan,
                       message: :magenta
                      )

  Logging.appenders.stdout("stdout",
                           auto_flushing: true,
                           layout:        Logging.layouts.pattern(
                             pattern:      pattern,
                             color_scheme: "bright"
                           )
                          ) if config.log_to.include? "stdout"

  if config.log_to.include? "file"
    if AppConfig.environment.logging.logrotate.enable?
      Logging.appenders.rolling_file("file",
                                     filename:      config.paths["log"].first,
                                     keep:          AppConfig.environment.logging.logrotate.days.to_i,
                                     age:           "daily",
                                     truncate:      false,
                                     auto_flushing: true,
                                     layout:        layout
                                    )
    else
      Logging.appenders.file("file",
                             filename:      config.paths["log"].first,
                             truncate:      false,
                             auto_flushing: true,
                             layout:        layout
                            )
    end
  end

  Logging.logger.root.appenders = config.log_to unless config.log_to.empty?

  Logging.logger.root.level = config.log_level

  Logging.logger[ActiveRecord::Base].level = AppConfig.environment.logging.debug.sql? ? :debug : :info
  Logging.logger["XMLLogger"].level = AppConfig.environment.logging.debug.federation? ? :debug : :info

  if defined? PhusionPassenger
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      Logging.reopen if forked
    end
  end
end
