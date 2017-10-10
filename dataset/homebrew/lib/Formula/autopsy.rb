class Autopsy < Formula
  desc "Graphical interface to Sleuth Kit investigation tools"
  homepage "http://www.sleuthkit.org/autopsy/index.php"
  url "https://downloads.sourceforge.net/project/autopsy/autopsy/2.24/autopsy-2.24.tar.gz"
  sha256 "ab787f519942783d43a561d12be0554587f11f22bc55ab79d34d8da703edc09e"

  depends_on "sleuthkit"
  depends_on "afflib" => :optional
  depends_on "libewf" => :optional

  patch :DATA

  def autcfg; <<-EOS.undent

    $USE_STIMEOUT = 0;
    $STIMEOUT = 3600;

    $CTIMEOUT = 15;

    $SAVE_COOKIE = 1;

    $INSTALLDIR = '#{prefix}';


    $GREP_EXE = '/usr/bin/grep';
    $FILE_EXE = '/usr/bin/file';
    $MD5_EXE = '/sbin/md5';
    $SHA1_EXE = '/usr/bin/shasum';


    $TSKDIR = '/usr/local/bin/';

    $NSRLDB = '';

    $LOCKDIR = '#{var}/lib/autopsy';
    EOS
  end

  def install
    (var+"lib/autopsy").mkpath
    mv "lib", "libexec"
    prefix.install %w[global.css help libexec pict]
    prefix.install Dir["*.txt"]
    (prefix+"conf.pl").write autcfg
    inreplace "base/autopsy.base", "/tmp/autopsy", prefix
    inreplace "base/autopsy.base", "lib/define.pl", "#{libexec}/define.pl"
    bin.install "base/autopsy.base" => "autopsy"
  end

  def caveats; <<-EOS.undent
    By default, the evidence locker is in:
    EOS
  end
end

__END__
diff --git a/base/autopsy.base b/base/autopsy.base
index 3b3bbdc..a0d2632 100644
--- a/base/autopsy.base
+++ b/base/autopsy.base
@@ -1,3 +1,6 @@
+#!/usr/bin/perl -wT
+use lib '/tmp/autopsy/';
+use lib '/tmp/autopsy/libexec/';
