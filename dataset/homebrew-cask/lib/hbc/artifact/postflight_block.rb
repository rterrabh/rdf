class Hbc::Artifact::PostflightBlock < Hbc::Artifact::Base
  def self.me?(cask)
    cask.artifacts[:postflight].any? ||
      cask.artifacts[:uninstall_postflight].any?
  end

  def install_phase
    @cask.artifacts[:postflight].each do |block|
      #nodyna <instance_eval-2847> <IEV COMPLEX (block execution)>
      Hbc::DSL::Postflight.new(@cask).instance_eval &block
    end
  end

  def uninstall_phase
    @cask.artifacts[:uninstall_postflight].each do |block|
      #nodyna <instance_eval-2848> <IEV COMPLEX (block execution)>
      Hbc::DSL::UninstallPostflight.new(@cask).instance_eval &block
    end
  end
end
