class Splint < Formula
  desc "Secure Programming Lint"
  homepage "http://www.splint.org/"
  url "http://www.splint.org/downloads/splint-3.1.2.src.tgz"
  sha256 "c78db643df663313e3fa9d565118391825dd937617819c6efc7966cdf444fb0a"

  patch :DATA

  def install
    ENV.j1 # build is not parallel-safe
    system "./configure", "--disable-debug",
                          "--prefix=#{prefix}",
                          "--infodir=#{info}",
                          "--mandir=#{man}"
    system "make"
    system "make", "install"
  end

  test do
    path = testpath/"test.c"
    path.write <<-EOS.undent
      int main()
      {
          char c;
          printf("%c", c);
          return 0;
      }
    EOS

    output = `#{bin}/splint #{path} 2>&1`
    assert output.include?("5:18: Variable c used before definition")
    assert_equal 1, $?.exitstatus
  end
end


__END__
diff --git a/src/osd.c b/src/osd.c
index ebe214a..4ba81d5 100644
--- a/src/osd.c
+++ b/src/osd.c
@@ -516,7 +516,7 @@ osd_getPid ()
   int pid = _getpid ();
-  __pid_t pid = getpid ();
+  pid_t pid = getpid ();

   return (int) pid;
