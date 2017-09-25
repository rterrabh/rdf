class Erlang17Requirement < Requirement
  fatal true
  env :userpaths
  default_formula "erlang"

  satisfy do
    erl = which("erl")
    next unless erl
    `#{erl} -noshell -eval 'io:fwrite("~s~n", [erlang:system_info(otp_release)]).' -s erlang halt | grep -q '^1[789]'`
    $?.exitstatus == 0
  end

  def message; <<-EOS.undent
    Erlang 17+ is required to install.

    You can install this with:
      brew install erlang

    Or you can use an official installer from:
      http://www.erlang.org/
    EOS
  end
end

class Elixir < Formula
  desc "Functional metaprogramming aware language built on Erlang VM"
  homepage "http://elixir-lang.org/"
  url "https://github.com/elixir-lang/elixir/archive/v1.0.5.tar.gz"
  sha256 "5ce5c226b3d11d751b41ad79b915b86f13f8a1b89ef3e733321d3f46ff4d81b8"

  head "https://github.com/elixir-lang/elixir.git"

  bottle do
    sha256 "e25c7d985147de85b0e8d0adfc12f92c34af748af2c58557ad4f34aa7f96e63b" => :yosemite
    sha256 "2c5931b0eea75db2e22c6a20cb17c632c5052d03254bd355c0db5b9dbd90ba51" => :mavericks
    sha256 "05bafa8e03110933685d0f8888a5b461a8ce51427c7cf23a069995a9a9698794" => :mountain_lion
  end

  depends_on Erlang17Requirement

  def install
    system "make"
    bin.install Dir["bin/*"] - Dir["bin/*.{bat,ps1}"]

    Dir.glob("lib/*/ebin") do |path|
      app = File.basename(File.dirname(path))
      (lib/app).install path
    end
  end

  test do
    system "#{bin}/elixir", "-v"
  end
end
