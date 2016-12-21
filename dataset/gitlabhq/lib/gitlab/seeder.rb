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
      #nodyna <ID:eval-1> <eval VERY LOW ex1>
      eval(code)
    end
  end
end
