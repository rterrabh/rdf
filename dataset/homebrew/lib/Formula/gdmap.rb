class Gdmap < Formula
  desc "Tool to inspect the used space of folders"
  homepage "https://sourceforge.net/projects/gdmap/"
  url "https://downloads.sourceforge.net/project/gdmap/gdmap/0.8.1/gdmap-0.8.1.tar.gz"
  sha256 "a200c98004b349443f853bf611e49941403fce46f2335850913f85c710a2285b"

  depends_on "pkg-config" => :build
  depends_on "intltool" => :build
  depends_on "gettext"
  depends_on "glib"
  depends_on "gtk+"

  patch :DATA

  def install
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"

    system "make", "install"
  end

  test do
    system "#{bin}/gdmap", "--help"
  end
end

__END__
diff --git a/configure b/configure
index fc7ed80..bb408d3 100755
--- a/configure
+++ b/configure
@@ -8225,7 +8225,7 @@ else
 echo "${ECHO_T}yes" >&6; }
         :
 fi
-UI_CFLAGS="$UI_CFLAGS -DGTK_DISABLE_DEPRECATED"
+#UI_CFLAGS="$UI_CFLAGS -DGTK_DISABLE_DEPRECATED"



diff --git a/src/gui_main.c b/src/gui_main.c
index efe2239..91c2a14 100644
--- a/src/gui_main.c
+++ b/src/gui_main.c
@@ -11,7 +11,6 @@

-#include <sys/vfs.h>
