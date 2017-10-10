require "whenever/capistrano/v2/recipes"

Capistrano::Configuration.instance(:must_exist).load do
  before "deploy:finalize_update", "whenever:update_crontab"
  after "deploy:rollback", "whenever:update_crontab"
end
