class Ipmitool < Formula
  desc "Utility for IPMI control with kernel driver or LAN interface"
  homepage "http://ipmitool.sourceforge.net/"
  url "https://downloads.sourceforge.net/project/ipmitool/ipmitool/1.8.15/ipmitool-1.8.15.tar.bz2"
  sha256 "4acd2df5f8740fef5c032cebee0113ec4d3bbef04a6f4dbfaf7fcc7f3eb08c40"

  depends_on "openssl"

  def install
    inreplace "include/ipmitool/ipmi_user.h", "HAVE_PRAGMA_PACK", "DISABLE_PRAGMA_PACK"
    inreplace "src/plugins/ipmi_intf.c", "s6_addr16", "s6_addr"

    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--mandir=#{man}"
    system "make", "install"
  end
end
