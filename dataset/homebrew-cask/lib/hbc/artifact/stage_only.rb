class Hbc::Artifact::StageOnly < Hbc::Artifact::Base
  def self.artifact_dsl_key
    :stage_only
  end

  def install_phase
  end

  def uninstall_phase
  end
end
