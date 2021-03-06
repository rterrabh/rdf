class Bash < Formula
  desc "Bash (Bourne-again SHell) is a UNIX command interpreter"
  homepage "https://www.gnu.org/software/bash/"

  head "http://git.savannah.gnu.org/r/bash.git"

  stable do
    url "http://ftpmirror.gnu.org/bash/bash-4.3.tar.gz"
    mirror "https://ftp.gnu.org/gnu/bash/bash-4.3.tar.gz"
    sha256 "afc687a28e0e24dc21b988fa159ff9dbcf6b7caa92ade8645cc6d5605cd024d4"
    version "4.3.42"

    patch do
      url "https://gist.githubusercontent.com/dunn/a8986687991b57eb3b25/raw/76dd864812e821816f4b1c18e3333c8fced3919b/bash-4.3.42.diff"
      sha256 "2eeb9b3ed71f1e13292c2212b6b8036bc258c58ec9c82eec7a86a091b05b15d2"
    end
  end

  bottle do
    sha256 "e4c37730749adcdbc274fa57b62300f2f2c68078b962cfd196a7e8f0764b543c" => :yosemite
    sha256 "4078f42a58506e67d25ec0f82f85efd265bf2eac606a9aeca50a7e7bd5b7e025" => :mavericks
    sha256 "4fded417b56f73ffcf48b5d05bc22e04beb521c7f91f4d6b5671876173584c27" => :mountain_lion
  end

  depends_on "readline"

  def install
    ENV.append_to_cflags "-DSSH_SOURCE_BASHRC"

    system "./configure", "--prefix=#{prefix}", "--with-installed-readline"
    system "make", "install"
  end

  def caveats; <<-EOS.undent
    In order to use this build of bash as your login shell,
    it must be added to /etc/shells.
    EOS
  end

  test do
    assert_equal "hello", shell_output("#{bin}/bash -c \"echo hello\"").strip
  end
end
