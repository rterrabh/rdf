class JohnJumbo < Formula
  desc "Enhanced version of john, a UNIX password cracker"
  homepage "http://www.openwall.com/john/"
  url "http://openwall.com/john/j/john-1.8.0-jumbo-1.tar.xz"
  sha256 "bac93d025995a051f055adbd7ce2f1975676cac6c74a6c7a3ee4cfdd9c160923"
  version "1.8.0"

  bottle do
    revision 3
    sha256 "b5d13ea393e16a474bcd69d0d7fd14038effac04d423b6041d9dbb76dd6325ae" => :yosemite
    sha256 "d8303c4412f7354e2778ef58ed8eb366d9d474491b255ad5f32d27946df174e6" => :mavericks
    sha256 "c3a9c980f5725ec08854cdce75b91af58bb4f61c8a30e2d700de45e0a5b9ff3c" => :mountain_lion
  end

  conflicts_with "john", :because => "both install the same binaries"

  option "without-completion", "bash/zsh completion will not be installed"

  depends_on "pkg-config" => :build
  depends_on "openssl"
  depends_on "gmp"

  patch :DATA

  fails_with :llvm do
    build 2334
    cause "Don't remember, but adding this to whitelist 2336."
  end

  fails_with :gcc do
    cause "Upstream have a hacky workaround for supporting gcc that we can't use."
  end

  def install
    cd "src" do
      args = []
      if build.bottle?
        args << "--disable-native-tests" << "--disable-native-macro"
      end
      system "./configure", *args
      system "make", "clean"
      system "make", "-s", "CC=#{ENV.cc}"
    end

    rm "README"
    prefix.install "doc/README"
    doc.install Dir["doc/*"]

    (share/"john").install Dir["run/*"]
    bin.install_symlink share/"john/john"

    if build.with? "completion"
      bash_completion.install share/"john/john.bash_completion" => "john.bash"
      zsh_completion.install share/"john/john.zsh_completion" => "_john"
    end

    mv share/"john/john.conf", share/"john/john.ini"
  end

  test do
    touch "john2.pot"
    system "echo dave:`printf secret | /usr/bin/openssl md5` > test"
    assert_match(/secret/, shell_output("#{bin}/john --pot=#{testpath}/john2.pot --format=raw-md5 test"))
    assert_match(/secret/, (testpath/"john2.pot").read)
  end
end


__END__
--- a/src/params.h	2012-08-30 13:24:18.000000000 -0500
+++ b/src/params.h	2012-08-30 13:25:13.000000000 -0500
@@ -70,15 +70,15 @@
  * notes above.
  */
-#define JOHN_SYSTEMWIDE			0
+#define JOHN_SYSTEMWIDE			1
 
-#define JOHN_SYSTEMWIDE_EXEC		"/usr/libexec/john"
+#define JOHN_SYSTEMWIDE_EXEC		"HOMEBREW_PREFIX/share/john"
-#define JOHN_SYSTEMWIDE_HOME		"/usr/share/john"
+#define JOHN_SYSTEMWIDE_HOME		"HOMEBREW_PREFIX/share/john"
