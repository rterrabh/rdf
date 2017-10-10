class Disco < Formula
  desc "Distributed computing framework based on the MapReduce paradigm"
  homepage "http://discoproject.org/"
  url "https://github.com/discoproject/disco/archive/0.5.4.tar.gz"
  sha256 "a1872b91fd549cea6e709041deb0c174e18d0e1ea36a61395be37e50d9df1f8f"

  bottle do
    cellar :any
    sha1 "f1a4e9775053971dac6ab3b183ebb13d6928c050" => :yosemite
    sha1 "286325ec178e1bd06a78127333c835a1bf5a2763" => :mavericks
    sha1 "da6e23c51a8ca6c353e83724746f0e11dba37a99" => :mountain_lion
  end

  depends_on :python if MacOS.version <= :snow_leopard
  depends_on "erlang"
  depends_on "simplejson" => :python if MacOS.version <= :leopard
  depends_on "libcmph"

  patch :DATA

  def install
    ENV["PYTHONPATH"] = lib+"python2.7/site-packages"

    inreplace "Makefile" do |s|
      s.change_make_var! "prefix", prefix
      s.change_make_var! "sysconfdir", etc
      s.change_make_var! "localstatedir", var
    end

    system "git init && git add master/rebar && git commit -a -m 'dummy commit'"

    system "make"
    system "make", "install"
    prefix.install %w[contrib doc examples]

    inreplace "#{etc}/disco/settings.py" do |s|
      s.gsub!("Cellar/disco/"+version+"/", "")
    end

    bin.env_script_all_files(libexec+"bin", :PYTHONPATH => ENV["PYTHONPATH"])
  end

  test do
    system "#{bin}/disco"
  end

  def caveats
    <<-EOS.undent
      Please copy #{etc}/disco/settings.py to ~/.disco and edit it if necessary.
      The DDFS_*_REPLICA settings have been set to 1 assuming a single-machine install.
      Please see http://discoproject.org/doc/disco/start/install.html for further instructions.
    EOS
  end
end

__END__
diff -rupN disco-0.4.5/conf/gen.settings.sh my-edits/disco-0.4.5/conf/gen.settings.sh
--- disco-0.4.5/conf/gen.settings.sh  2013-03-28 12:21:30.000000000 -0400
+++ my-edits/disco-0.4.5/conf/gen.settings.sh 2013-04-10 23:10:00.000000000 -0400
@@ -23,8 +23,11 @@ DISCO_PORT = 8989

-DDFS_TAG_MIN_REPLICAS = 3
-DDFS_TAG_REPLICAS     = 3
-DDFS_BLOB_REPLICAS    = 3
+# Settings appropriate for single-node operation
+DDFS_TAG_MIN_REPLICAS = 1
+DDFS_TAG_REPLICAS     = 1
+DDFS_BLOB_REPLICAS    = 1
+
+DISCO_MASTER_HOST     = "localhost"

 EOF
