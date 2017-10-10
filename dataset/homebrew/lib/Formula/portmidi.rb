class Portmidi < Formula
  desc "Cross-platform library for real-time MIDI I/O"
  homepage "http://sourceforge.net/apps/trac/portmedia/wiki/portmidi"
  url "https://downloads.sourceforge.net/project/portmedia/portmidi/217/portmidi-src-217.zip"
  sha256 "08e9a892bd80bdb1115213fb72dc29a7bf2ff108b378180586aa65f3cfd42e0f"

  option "with-java", "Build java based app and bindings. You need the Java SDK for this."

  depends_on "cmake" => :build
  depends_on :python => :optional
  depends_on "Cython" => :python if build.with? "python"

  patch :DATA if build.without? "java"

  def install
    inreplace "pm_mac/Makefile.osx", "PF=/usr/local", "PF=#{prefix}"

    include.mkpath
    lib.mkpath

    inreplace "pm_common/CMakeLists.txt", "set(CMAKE_OSX_SYSROOT /Developer/SDKs/MacOSX10.5.sdk CACHE", "set(CMAKE_OSX_SYSROOT /#{MacOS.sdk_path} CACHE"

    system "make -f pm_mac/Makefile.osx"
    system "make -f pm_mac/Makefile.osx install"

    if build.with? "python"
      cd "pm_python" do
        inreplace "setup.py", "CHANGES = open('CHANGES.txt').read()", 'CHANGES = ""'
        inreplace "setup.py", "TODO = open('TODO.txt').read()", 'TODO = ""'
        ENV.append "CFLAGS", "-I#{include}"
        ENV.append "LDFLAGS", "-L#{lib}"
        system "python", "setup.py", "install", "--prefix=#{prefix}"
      end
    end
  end
end

__END__
diff --git a/pm_common/CMakeLists.txt b/pm_common/CMakeLists.txt
index e171047..b010c35 100644
--- a/pm_common/CMakeLists.txt
+++ b/pm_common/CMakeLists.txt
@@ -112,14 +112,9 @@ target_link_libraries(portmidi-static ${PM_NEEDED_LIBS})
 include_directories(${JAVA_INCLUDE_PATHS})

-set(JNISRC ${LIBSRC} ../pm_java/pmjni/pmjni.c)
-add_library(pmjni SHARED ${JNISRC})
-target_link_libraries(pmjni ${JNI_EXTRA_LIBS})
-set_target_properties(pmjni PROPERTIES EXECUTABLE_EXTENSION "jnilib")
-
 if(UNIX)
-  INSTALL(TARGETS portmidi-static pmjni
+  INSTALL(TARGETS portmidi-static
     LIBRARY DESTINATION /usr/local/lib
     ARCHIVE DESTINATION /usr/local/lib)
