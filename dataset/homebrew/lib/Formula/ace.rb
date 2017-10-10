class Ace < Formula
  desc "ADAPTIVE Communication Environment: OO network programming in C++"
  homepage "http://www.cse.wustl.edu/~schmidt/ACE.html"
  url "http://download.dre.vanderbilt.edu/previous_versions/ACE-6.3.0.tar.bz2"
  sha256 "e22b6adb1fdd0af45e1c78087d8fd24555b7dcbf0cd6a22b4b131a737602b561"

  bottle do
    sha1 "90cb518c4554949453de2eb406a7d1ef8fda3880" => :yosemite
    sha1 "2a58aa9a687ed6b8d3eef8f982b0c96554d85de7" => :mavericks
    sha1 "faa49b7abaf6661f0e4cff46715755985a4a980a" => :mountain_lion
  end

  def install

    name = MacOS.cat.to_s.delete "_"
    ln_sf "config-macosx-#{name}.h", "ace/config.h"
    ln_sf "platform_macosx_#{name}.GNU", "include/makeinclude/platform_macros.GNU"

    ENV["ACE_ROOT"] = buildpath
    ENV["DYLD_LIBRARY_PATH"] = "#{buildpath}/ace:#{buildpath}/lib"

    system "make", "-C", "ace", "-f", "GNUmakefile.ACE",
                   "INSTALL_PREFIX=#{prefix}",
                   "LDFLAGS=",
                   "DESTDIR=",
                   "INST_DIR=/ace",
                   "debug=0",
                   "shared_libs=1",
                   "static_libs=0",
                   "install"
  end
end
