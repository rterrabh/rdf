
Thread.new do
  file = "#{Rails.root}/tmp/restart"
  old_time = File.ctime(file).to_i if File.exists? file
  wait_seconds = 4

  if $PROGRAM_NAME =~ /thin/
    while true
      time = File.ctime(file).to_i if File.exists? file

      if old_time != time
        Rails.logger.info "attempting to reload #{$$} #{$PROGRAM_NAME} in #{wait_seconds} seconds"
        $shutdown = true
        sleep wait_seconds
        Rails.logger.info "restarting #{$$}"
        Process.kill("HUP", $$)
        break
      end

      sleep 1
    end
  end
end
