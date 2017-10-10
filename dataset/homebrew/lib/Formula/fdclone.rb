class Fdclone < Formula
  desc "Console-based file manager"
  homepage "http://hp.vector.co.jp/authors/VA012337/soft/fd/"
  url "http://hp.vector.co.jp/authors/VA012337/soft/fd/FD-3.01b.tar.gz"
  sha256 "d66d902cac9d4f64a91d42ceb487a138d544c9fd9cb2961730889cc8830303d4"

  depends_on "nkf" => :build

  patch :DATA

  def install
    ENV.j1
    system "make", "PREFIX=#{prefix}", "all"
    system "make", "MANTOP=#{man}", "install"

    %w[README FAQ HISTORY LICENSES TECHKNOW ToAdmin].each do |file|
      system "nkf", "-w", "--overwrite", file
      prefix.install "#{file}.eng" => file
      prefix.install file => "#{file}.ja"
    end

    share.install "_fdrc" => "fd2rc.dist"
  end

  def caveats; <<-EOS.undent
    To install the initial config file:
        install -c -m 0644 #{share}/fd2rc.dist ~/.fd2rc
    To set application messages to Japanese, edit your .fd2rc:
        MESSAGELANG="ja"
    EOS
  end
end

__END__
diff --git a/machine.h b/machine.h
index 8bc70ab..39b0d28 100644
--- a/machine.h
+++ b/machine.h
@@ -1449,4 +1449,6 @@ typedef unsigned long		u_long;

+#define USEDATADIR
+
diff --git a/custom.c b/custom.c
index d7a995f..45b96c6 100644
--- a/custom.c
+++ b/custom.c
@@ -566,7 +566,7 @@ static CONST envtable envlist[] = {
 	{"FD_URLKCODE", &urlkcode, DEFVAL(NOCNV), URLKC_E, T_KNAM},
-	{"FD_MESSAGELANG", &messagelang, DEFVAL(NOCNV), MESL_E, T_MESLANG},
+	{"FD_MESSAGELANG", &messagelang, DEFVAL("C"), MESL_E, T_MESLANG},
 	{"FD_SJISPATH", &sjispath, DEFVAL(SJISPATH), SJSP_E, T_KPATHS},
@@ -862,7 +862,9 @@ int no;
 		case T_MESLANG:
+			if (!cp) cp = def_str(no);
 			catname = cp;
+			chkcatalog();
 /*FALLTHRU*/
 		case T_KIN:
diff --git a/fd.h b/fd.h
index 08de84b..63cdaeb 100644
--- a/fd.h
+++ b/fd.h
@@ -104,16 +104,16 @@ extern char *_mtrace_file;
  *	variables nor run_com file nor command line option	*
  ****************************************************************/
-#define	SORTTYPE		0
-#define	DISPLAYMODE		0
-#define	SORTTREE		0
+#define	SORTTYPE		1
+#define	DISPLAYMODE		3
+#define	SORTTREE		1
-#define	ADJTTY			0
+#define	ADJTTY			1
@@ -155,7 +155,7 @@ extern char *_mtrace_file;
-#define	ANSICOLOR		0
+#define	ANSICOLOR		1
@@ -193,7 +193,7 @@ extern char *_mtrace_file;
-#define	UNICODEBUFFER		0
+#define	UNICODEBUFFER		1
diff --git a/_fdrc b/_fdrc
index 97aec7b..0a81bb9 100644
--- a/_fdrc
+++ b/_fdrc
@@ -7,8 +7,8 @@
 
-#	0: not sort (Default)
-#	1: alphabetical	9: alphabetical (reversal)
+#	0: not sort
+#	1: alphabetical	(Default) 9: alphabetical (reversal)
@@ -16,23 +16,23 @@
-#SORTTYPE=0
+#SORTTYPE=1
 
-#	0: normal (Default)
+#	0: normal
-#	3: sym-link status &	file type symbol
+#	3: sym-link status &	file type symbol (Default)
-#DISPLAYMODE=0
+#DISPLAYMODE=3
 
-#	0: not sort (Default)
-#	>= 1: sort according to SORTTYPE
-#SORTTREE=0
+#	0: not sort
+#	>= 1: sort according to SORTTYPE (Default)
+#SORTTREE=1
 
@@ -61,9 +61,9 @@
 
-#	0: not adjust (Default)
-#	>= 1: adjust
-#ADJTTY=0
+#	0: not adjust
+#	>= 1: adjust (Default)
+#ADJTTY=1
 
@@ -179,11 +179,11 @@
 
-#	0: monochrome (Default)
-#	1: color
+#	0: monochrome
+#	1: color (Default)
-#ANSICOLOR=0
+#ANSICOLOR=1
 
@@ -374,9 +374,9 @@
 
-#	0: not hold (Default)
-#	>= 1: hold
-#UNICODEBUFFER=0
+#	0: not hold
+#	>= 1: hold (Default)
+#UNICODEBUFFER=1
 
