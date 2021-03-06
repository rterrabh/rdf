class Polygen < Formula
  desc "Generate random sentences according to a given grammar"
  homepage "http://www.polygen.org"
  url "http://www.polygen.org/dist/polygen-1.0.6-20040628-src.zip"
  sha256 "703c483820b33a5d695e884e58e2723a660930180fde845f38d6135d247c64a5"

  depends_on "objective-caml" => :build

  def install
    cd "src" do
      inreplace "Makefile", '-e "open Absyn\n"', '"open Absyn"'
      system "make"
      bin.install "polygen"
    end
  end
end
