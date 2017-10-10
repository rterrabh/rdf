require "fpm/package"
require "backports"


class FPM::Package::Empty < FPM::Package
  def output(output_path)
    logger.warn("Your package has gone into the void.")
  end
  def to_s(fmt)
    return ""
  end
end
