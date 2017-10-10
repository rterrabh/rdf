class Virtualpg < Formula
  desc "Loadable dynamic extension for SQLite and SpatiaLite"
  homepage "https://www.gaia-gis.it/fossil/virtualpg/index"
  url "http://www.gaia-gis.it/gaia-sins/virtualpg-1.0.1.tar.gz"
  sha256 "9e6c4c6c1556b2ea2a1e4deda28909626c3a8b047c81d6b82c042abdb9a99ec8"

  depends_on "libspatialite"
  depends_on "postgis"

  def install
    inreplace "configure",
    "shrext_cmds='`test .$module = .yes && echo .so || echo .dylib`'",
    "shrext_cmds='.dylib'"

    system "./configure", "--enable-shared=yes",
                          "--disable-dependency-tracking",
                          "--with-pgconfig=#{Formula["postgresql"].opt_bin}/pg_config",
                          "--prefix=#{prefix}"
    system "make", "install"
  end

  test do
    system "echo \"SELECT load_extension('#{opt_lib}/mod_virtualpg');\" | #{Formula["sqlite"].opt_bin}/sqlite3"
  end
end
