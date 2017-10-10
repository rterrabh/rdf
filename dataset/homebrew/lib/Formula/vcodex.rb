class Vcodex < Formula
  desc "Standalone vczip command and vcodex library"
  homepage "http://www2.research.att.com/~astopen/download/ref/vcodex/vcodex.html"
  url "http://www2.research.att.com/~astopen/download/tgz/vcodex.2013-05-31.tgz",
    :user => "I accept www.opensource.org/licenses/eclipse:."
  sha256 "3d690a5596d4b1a3f1f99a3511fd8cc9d65fc2b63ce0178a8d23677e72c2f83d"
  version "2013-05-31"

  def install
    ENV.deparallelize
    system "/bin/sh ./Runmake"
    bin.install Dir["bin/vc*"]
    (include + "vcodex").install Dir["include/*.h"]
    lib.install Dir["lib/*.a"]
    man.install "man/man3"
  end

  def caveats; <<-EOS.undent
    We agreed to the Eclipse Public License 1.0 for you.
    If this is unacceptable you should uninstall.
    EOS
  end
end
