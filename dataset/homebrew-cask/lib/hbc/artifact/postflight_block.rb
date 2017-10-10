class Hbc::Artifact::PostflightBlock < Hbc::Artifact::Base
  def self.me?(cask)
    cask.artifacts[:postflight].any? ||
      cask.artifacts[:uninstall_postflight].any?
  end

  def install_phase
    @cask.artifacts[:postflight].each do |block|
      #nodyna <instance_eval-2847> <not yet classified>
      Hbc::DSL::Postflight.new(@cask).instance_eval &block
    end
  end

  def uninstall_phase
    @cask.artifacts[:uninstall_postflight].each do |block|
      #nodyna <instance_eval-2848> <not yet classified>
      Hbc::DSL::UninstallPostflight.new(@cask).instance_eval &block
    end
  end
end
