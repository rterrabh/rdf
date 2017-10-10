class TomeeJaxRs < Formula
  desc "TomeEE Web Profile plus JAX-RS"
  homepage "https://tomee.apache.org/"
  url "https://www.apache.org/dyn/closer.cgi?path=tomee/tomee-1.7.2/apache-tomee-1.7.2-jaxrs.tar.gz"
  version "1.7.2"
  sha256 "561ef98f69b312a03b305f37fd492ed59f9802137e2995ea57db98d438b0b9c8"

  def install
    rm_rf Dir["bin/*.bat"]
    rm_rf Dir["bin/*.bat.original"]
    rm_rf Dir["bin/*.exe"]

    prefix.install %w[NOTICE LICENSE RELEASE-NOTES RUNNING.txt]
    libexec.install Dir["*"]
    bin.install_symlink "#{libexec}/bin/startup.sh" => "tomee-jax-rs-startup"
  end

  def caveats; <<-EOS.undent
    The home of Apache TomEE JAX-RS is:
    To run Apache TomEE:
    EOS
  end

  test do
    system "#{opt_libexec}/bin/configtest.sh"
  end
end
