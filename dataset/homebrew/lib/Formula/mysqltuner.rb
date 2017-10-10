class Mysqltuner < Formula
  desc "Increase performance and stability of a MySQL installation"
  homepage "http://mysqltuner.com"
  url "https://github.com/major/MySQLTuner-perl/archive/v1.4.0.tar.gz"
  sha256 "8d5a03b64da2164c6bd93b79700c93db088a14155bcc8cb63c65d049909d793e"
  head "https://github.com/major/MySQLTuner-perl.git"

  def install
    bin.install "mysqltuner.pl" => "mysqltuner"
  end

  test do
    system "#{bin}/mysqltuner", "--help"
  end
end
