class CupsPdf < Formula
  desc "Print-to-PDF feature through CUPS"
  homepage "http://www.cups-pdf.de/"
  url "http://www.cups-pdf.de/src/cups-pdf_2.6.1.tar.gz"
  sha256 "04e17eb563dceea048e1a435edcbcf52faa5288f85e8390cd64d702edb6745f1"

  patch :DATA

  def install
    system "#{ENV.cc} #{ENV.cflags} -o cups-pdf src/cups-pdf.c"

    (etc+"cups").install "extra/cups-pdf.conf"
    (lib+"cups/backend").install "cups-pdf"
    (share+"cups/model").install "extra/CUPS-PDF.ppd"
  end

  def caveats; <<-EOF.undent
    In order to use cups-pdf with the Mac OS X printing system change the file
    permissions, symlink the necessary files to their System location and
    have cupsd re-read its configuration using:

    chmod 0700 #{lib}/cups/backend/cups-pdf
    sudo chown root #{lib}/cups/backend/cups-pdf
    sudo ln -sf #{etc}/cups/cups-pdf.conf /etc/cups/cups-pdf.conf
    sudo ln -sf #{lib}/cups/backend/cups-pdf /usr/libexec/cups/backend/cups-pdf
    sudo chmod -h 0700 /usr/libexec/cups/backend/cups-pdf
    sudo ln -sf #{share}/cups/model/CUPS-PDF.ppd /usr/share/cups/model/CUPS-PDF.ppd

    sudo mkdir -p /var/spool/cups-pdf/${USER}
    sudo chown ${USER}:staff /var/spool/cups-pdf/${USER}
    ln -s /var/spool/cups-pdf/${USER} ${HOME}/Documents/cups-pdf
    sudo killall -HUP cupsd

    NOTE: When uninstalling cups-pdf these symlinks need to be removed manually.
    EOF
  end
end

__END__
diff --git a/extra/cups-pdf.conf b/extra/cups-pdf.conf
index cfb4b78..cc8410d 100644
--- a/extra/cups-pdf.conf
+++ b/extra/cups-pdf.conf
@@ -40,7 +40,7 @@
 
-#Out /var/spool/cups-pdf/${USER}
+Out ${HOME}/Documents/cups-pdf/
 
@@ -82,7 +82,7 @@
 
-#Cut 3
+Cut -1
 
@@ -91,7 +91,7 @@
 
-#Label 0
+Label 1
 
@@ -180,7 +180,7 @@
 
-#Grp lp
+Grp _lp
 
 
@@ -220,28 +220,28 @@
 
-#GhostScript /usr/bin/gs
+GhostScript /usr/bin/pstopdf
 
 
-#GSTmp /var/tmp
+GSTmp /tmp
 
 
-#GSCall %s -q -dCompatibilityLevel=%s -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -sOutputFile="%s" -dAutoRotatePages=/PageByPage -dAutoFilterColorImages=false -dColorImageFilter=/FlateEncode -dPDFSETTINGS=/prepress -c .setpdfwrite -f %s
+GSCall %s %s -o %s %s
 
 
-#PDFVer 1.4
+PDFVer 
 
