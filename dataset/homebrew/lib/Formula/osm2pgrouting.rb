class Osm2pgrouting < Formula
  desc "Import OSM data into pgRouting database"
  homepage "http://pgrouting.org/docs/tools/osm2pgrouting.html"
  url "https://github.com/pgRouting/osm2pgrouting/archive/v2.0.0.tar.gz"
  sha256 "0438624f02b58b14388962d6b538187f16993a5e1e9766acf8099dc0255dfb34"
  head "https://github.com/pgRouting/osm2pgrouting.git"

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on :postgresql

  def install
    inreplace "CMakeLists.txt" do |s|
      s.gsub! "/usr/share/osm2pgrouting", "."
      s.gsub! "/usr/share/bin", "bin"
    end

    system "cmake", ".", *std_cmake_args
    system "make"
    system "make", "install"
  end
end
