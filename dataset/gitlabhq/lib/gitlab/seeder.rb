module Gitlab
  class Seeder
    def self.quiet
      mute_mailer
      SeedFu.quiet = true
      yield
      SeedFu.quiet = false
      puts "\nOK".green
    end

    def self.by_user(user)
      yield
    end

    def self.mute_mailer
      code = <<-eos
def Notify.delay
  self
end
      eos
      #nodyna <eval-494> <EV TRIVIAL (method definition)>
      eval(code)
    end
  end
end
