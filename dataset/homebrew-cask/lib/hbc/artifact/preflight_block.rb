class Hbc::Artifact::PreflightBlock < Hbc::Artifact::Base
  def self.me?(cask)
    cask.artifacts[:preflight].any? ||
      cask.artifacts[:uninstall_preflight].any?
  end

  def install_phase
    @cask.artifacts[:preflight].each do |block|
      #nodyna <instance_eval-2845> <IEV COMPLEX (block execution)>
      Hbc::DSL::Preflight.new(@cask).instance_eval &block
    end
  end

  def uninstall_phase
    @cask.artifacts[:uninstall_preflight].each do |block|
      #nodyna <instance_eval-2846> <IEV COMPLEX (block execution)>
      Hbc::DSL::UninstallPreflight.new(@cask).instance_eval &block
    end
  end
end
