class AppscaleTools < Formula
  desc "Command-line tools for working with AppScale"
  homepage "https://github.com/AppScale/appscale-tools"
  url "https://github.com/AppScale/appscale-tools/archive/2.3.1.tar.gz"
  sha256 "f24460657d46cb84d657e900999349fbd789d2bc6546a866932cfc20fe195a58"
  head "https://github.com/AppScale/appscale-tools.git"

  bottle do
    cellar :any
    sha256 "c05f8f8571caa73f5d02bebe2eea467d1613f77109d73f3475f18cd79561d34c" => :yosemite
    sha256 "dd00c04bdc9d7ea38a1295e742a87e28272d8b903f0249243d39b2ec18b30332" => :mavericks
    sha256 "138a2bfa6c45de2f6567fb8b6116cca31a46435de776771a81f3ec83e6cd68a9" => :mountain_lion
  end

  depends_on :python if MacOS.version <= :snow_leopard
  depends_on "libyaml"

  resource "termcolor" do
    url "https://pypi.python.org/packages/source/t/termcolor/termcolor-1.1.0.tar.gz"
    sha256 "1d6d69ce66211143803fbc56652b41d73b4a400a2891d7bf7a1cdf4c02de613b"
  end

  resource "SOAPpy" do
    url "https://pypi.python.org/packages/source/S/SOAPpy/SOAPpy-0.12.22.zip"
    sha256 "e70845906bb625144ae6a8df4534d66d84431ff8e21835d7b401ec6d8eb447a5"
  end

  # dependencies for soappy
  resource "wstools" do
    url "https://pypi.python.org/packages/source/w/wstools/wstools-0.4.3.tar.gz"
    sha256 "578b53e98bc8dadf5a55dfd1f559fd9b37a594609f1883f23e8646d2d30336f8"
  end
  resource "defusedxml" do
    url "https://pypi.python.org/packages/source/d/defusedxml/defusedxml-0.4.1.tar.gz"
    sha256 "cd551d5a518b745407635bb85116eb813818ecaf182e773c35b36239fc3f2478"
  end

  resource "pyyaml" do
    url "https://pypi.python.org/packages/source/P/PyYAML/PyYAML-3.11.tar.gz"
    sha256 "c36c938a872e5ff494938b33b14aaa156cb439ec67548fcab3535bb78b0846e8"
  end

  resource "boto" do
    url "https://pypi.python.org/packages/source/b/boto/boto-2.38.0.tar.gz"
    sha256 "d9083f91e21df850c813b38358dc83df16d7f253180a1344ecfedce24213ecf2"
  end

  resource "argparse" do
    url "https://pypi.python.org/packages/source/a/argparse/argparse-1.3.0.tar.gz"
    sha256 "b3a79a23d37b5a02faa550b92cbbbebeb4aa1d77e649c3eb39c19abf5262da04"
  end

  resource "google-api-python-client" do
    url "https://pypi.python.org/packages/source/g/google-api-python-client/google-api-python-client-1.4.0.tar.gz"
    sha256 "695c046789540db5ce4deefe3836e78a2cc002d5e10a41b936c6907f4ec9c96c"
  end

  # dependencies for google-api-python-client
  resource "oauth2client" do
    url "https://pypi.python.org/packages/source/o/oauth2client/oauth2client-1.4.7.tar.gz"
    sha256 "b63550a242ea25ec027a261c2f5667d52de268f52c3f0c6ce60850ad45492031"
  end
  resource "six" do
    url "https://pypi.python.org/packages/source/s/six/six-1.9.0.tar.gz"
    sha256 "e24052411fc4fbd1f672635537c3fc2330d9481b18c0317695b46259512c91d5"
  end
  resource "uritemplate" do
    url "https://pypi.python.org/packages/source/u/uritemplate/uritemplate-0.6.tar.gz"
    sha256 "a30e230aeb7ebedbcb5da9999a17fa8a30e512e6d5b06f73d47c6e03c8e357fd"
  end

  resource "httplib2" do
    url "https://pypi.python.org/packages/source/h/httplib2/httplib2-0.9.1.tar.gz"
    sha256 "bc6339919a5235b9d1aaee011ca5464184098f0c47c9098001f91c97176583f5"
  end

  resource "python-gflags" do
    url "https://pypi.python.org/packages/source/p/python-gflags/python-gflags-2.0.tar.gz"
    sha256 "0dff6360423f3ec08cbe3bfaf37b339461a54a21d13be0dd5d9c9999ce531078"
  end

  def install
    ENV.prepend_create_path "PYTHONPATH", libexec/"vendor/lib/python2.7/site-packages"
    resources.each do |r|
      r.stage do
        system "python", *Language::Python.setup_install_args(libexec/"vendor")
      end
    end

    ENV.prepend_create_path "PYTHONPATH", libexec/"lib/python2.7/site-packages"
    system "python", *Language::Python.setup_install_args(libexec)

    bin.install Dir[libexec/"bin/*"]
    bin.env_script_all_files(libexec/"bin", :PYTHONPATH => ENV["PYTHONPATH"])
  end

  test do
    system bin/"appscale", "help"
    system bin/"appscale", "init", "cloud"
  end
end
