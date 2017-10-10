class Makensis < Formula
  desc "System to create Windows installers"
  homepage "http://nsis.sourceforge.net/"
  url "https://downloads.sourceforge.net/project/nsis/NSIS%202/2.46/nsis-2.46-src.tar.bz2"
  sha256 "f5f9e5e22505e44b25aea14fe17871c1ed324c1f3cc7a753ef591f76c9e8a1ae"

  depends_on "scons" => :build

  patch :DATA

  resource "nsis" do
    url "https://downloads.sourceforge.net/project/nsis/NSIS%202/2.46/nsis-2.46.zip"
    sha256 "ced6561f8aed81c8f3d6bc5a33684e03ca36a618110c0a849880c703337f26cc"
  end

  def install
    ENV.libstdcxx if ENV.compiler == :clang

    scons "STRIP=0", "makensis"
    bin.install "build/release/makensis/makensis"
    (share/"nsis").install resource("nsis")
  end
end

__END__
diff --git a/SCons/config.py b/SCons/config.py
index a344456..37c575b 100755
--- a/SCons/config.py
+++ b/SCons/config.py
@@ -1,3 +1,5 @@
+import os
+
 Import('defenv')
 
@@ -440,6 +442,9 @@ Help(cfg.GenerateHelpText(defenv))
 env = Environment()
 cfg.Update(env)
 
+defenv['CC'] = os.environ['CC']
+defenv['CXX'] = os.environ['CXX']
+
 def AddValuedDefine(define):
   defenv.Append(NSIS_CPPDEFINES = [(define, env[define])])
 
