Spring.after_fork do
  Discourse.after_fork
end
Spring::Commands::Rake.environment_matchers["spec"] = "test"
