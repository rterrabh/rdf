class Libpqxx < Formula
  desc "C++ connector for PostgreSQL"
  homepage "http://pqxx.org/development/libpqxx/"
  url "http://pqxx.org/download/software/libpqxx/libpqxx-4.0.1.tar.gz"
  sha256 "097ceda2797761ce517faa5bee186c883df1c407cb2aada613a16773afeedc38"

  bottle do
    cellar :any
    revision 1
    sha1 "dfd78c4be99cf1b24cd99fa01a8dcb97afb18557" => :yosemite
    sha1 "730d222c2c3329f894edc25df8052d0e6ad8f460" => :mavericks
    sha1 "3061cee2fd2c387febcbf02a08820d56b8abbda7" => :mountain_lion
  end

  depends_on "pkg-config" => :build
  depends_on :postgresql

  patch :DATA

  def install
    system "./configure", "--prefix=#{prefix}", "--enable-shared"
    system "make", "install"
  end
end

__END__
--- a/tools/maketemporary.orig	2009-07-04 00:38:30.000000000 -0500
+++ b/tools/maketemporary	2012-03-18 01:13:26.000000000 -0500
@@ -5,7 +5,7 @@
 TMPDIR="${TMPDIR:-/tmp}"
 export TMPDIR

-T="`mktemp`"
+T="`mktemp 2>/dev/null`"
 if test -z "$T" ; then
	T="`mktemp -t pqxx.XXXXXX`"
 fi
--- a/configure.orig	2011-11-27 05:12:25.000000000 -0600
+++ b/configure	2012-03-18 01:09:08.000000000 -0500
@@ -15204,7 +15204,7 @@
 fi


- if /bin/true; then
+ if /usr/bin/true; then
   BUILD_REFERENCE_TRUE=
   BUILD_REFERENCE_FALSE='#'
 else
@@ -15290,7 +15290,7 @@
 fi


- if /bin/true; then
+ if /usr/bin/true; then
   BUILD_TUTORIAL_TRUE=
   BUILD_TUTORIAL_FALSE='#'
 else
@@ -15299,7 +15299,7 @@
 fi

 else
- if /bin/false; then
+ if /usr/bin/false; then
   BUILD_REFERENCE_TRUE=
   BUILD_REFERENCE_FALSE='#'
 else
@@ -15307,7 +15307,7 @@
   BUILD_REFERENCE_FALSE=
 fi

- if /bin/false; then
+ if /usr/bin/false; then
   BUILD_TUTORIAL_TRUE=
   BUILD_TUTORIAL_FALSE='#'
 else
