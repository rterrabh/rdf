require "dependency"

class LD64Dependency < Dependency
  def initialize(name = "ld64", tags = [:build], env_proc = nil)
    super
    @env_proc = proc { ENV.ld64 }
  end
end
