module Utils
  def self.git_available?
    git = which("git")
    return false if git.nil?
    return false if git == "/usr/bin/git" && !OS::Mac.has_apple_developer_tools?
    true
  end

  def self.ensure_git_installed!
    return if git_available?

    require "cmd/install"
    begin
      oh1 "Installing git"
      Homebrew.perform_preinstall_checks
      Homebrew.install_formula(Formulary.factory("git"))
    rescue
      raise "Git is unavailable"
    end
  end
end
