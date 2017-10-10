class Wxmac < Formula
  desc "wxWidgets, a cross-platform C++ GUI toolkit (for OS X)"
  homepage "https://www.wxwidgets.org"
  url "https://downloads.sourceforge.net/project/wxwindows/3.0.2/wxWidgets-3.0.2.tar.bz2"
  sha256 "346879dc554f3ab8d6da2704f651ecb504a22e9d31c17ef5449b129ed711585d"

  bottle do
    revision 10
    sha256 "477e8d5fccd025ec8c30a72b3d201eedb1d1f73f784bdeb1bb0e6d8c7df68e77" => :yosemite
    sha256 "21bff32ebe73902c152b03c8ba16a54df97f82c068827c85360db5e9413c929a" => :mavericks
    sha256 "6e5b9d09d115f105648039423baa48227f0df4a65abd8fca852092452a40a067" => :mountain_lion
  end

  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libtiff"

  option "with-stl", "use standard C++ classes for everything"
  option "with-static", "build static libraries"

  patch :DATA

  def install
    ENV.universal_binary
    args = [
      "--disable-debug",
      "--prefix=#{prefix}",
      "--enable-unicode",
      "--enable-std_string",
      "--enable-display",
      "--with-opengl",
      "--with-osx_cocoa",
      "--with-libjpeg",
      "--with-libtiff",
      "--without-liblzma",
      "--with-libpng",
      "--with-zlib",
      "--enable-dnd",
      "--enable-clipboard",
      "--enable-webkit",
      "--enable-svg",
      MacOS.prefer_64_bit? ? "--disable-mediactrl" : "--enable-mediactrl",
      "--enable-graphics_ctx",
      "--enable-controls",
      "--enable-dataviewctrl",
      "--with-expat",
      "--with-macosx-version-min=#{MacOS.version}",
      "--enable-universal_binary=#{Hardware::CPU.universal_archs.join(",")}",
      "--disable-precomp-headers",
      "--disable-monolithic"
    ]

    args << "--enable-stl" if build.with? "stl"

    if build.with? "static"
      args << "--disable-shared"
    else
      args << "--enable-shared"
    end

    system "./configure", *args
    system "make", "install"
  end

  test do
    system "wx-config", "--libs"
  end
end

__END__

diff --git a/include/wx/defs.h b/include/wx/defs.h
index 397ddd7..d128083 100644
--- a/include/wx/defs.h
+++ b/include/wx/defs.h
@@ -3169,12 +3169,20 @@ DECLARE_WXCOCOA_OBJC_CLASS(UIImage);
 DECLARE_WXCOCOA_OBJC_CLASS(UIEvent);
 DECLARE_WXCOCOA_OBJC_CLASS(NSSet);
 DECLARE_WXCOCOA_OBJC_CLASS(EAGLContext);
+DECLARE_WXCOCOA_OBJC_CLASS(UIWebView);
 
 typedef WX_UIWindow WXWindow;
 typedef WX_UIView WXWidget;
 typedef WX_EAGLContext WXGLContext;
 typedef WX_NSString* WXGLPixelFormat;
 
+typedef WX_UIWebView OSXWebViewPtr;
+
+#endif
+
+#if wxOSX_USE_COCOA_OR_CARBON
+DECLARE_WXCOCOA_OBJC_CLASS(WebView);
+typedef WX_WebView OSXWebViewPtr;
 
diff --git a/include/wx/html/webkit.h b/include/wx/html/webkit.h
index 8700367..f805099 100644
--- a/include/wx/html/webkit.h
+++ b/include/wx/html/webkit.h
@@ -18,7 +18,6 @@
 
-DECLARE_WXCOCOA_OBJC_CLASS(WebView); 
 
 // ----------------------------------------------------------------------------
 // Web Kit Control
@@ -107,7 +106,7 @@ private:
     wxString m_currentURL;
     wxString m_pageTitle;
 
-    WX_WebView m_webView;
+    OSXWebViewPtr m_webView;
 
     // we may use this later to setup our own mouse events,
     // so leave it in for now.
diff --git a/include/wx/osx/webview_webkit.h b/include/wx/osx/webview_webkit.h
index 803f8b0..438e532 100644
--- a/include/wx/osx/webview_webkit.h
+++ b/include/wx/osx/webview_webkit.h
@@ -158,7 +158,7 @@ private:
     wxWindowID m_windowID;
     wxString m_pageTitle;
 
-    wxObjCID m_webView;
+    OSXWebViewPtr m_webView;
 
     // we may use this later to setup our own mouse events,
     // so leave it in for now.
