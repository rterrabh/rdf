class Bibclean < Formula
  desc "BibTeX bibliography file pretty printer and syntax checker"
  homepage "http://www.math.utah.edu/~beebe/software/bibclean/bibclean-03.html#HDR.3"
  url "http://ftp.math.utah.edu/pub/bibclean/bibclean-2.16.tar.gz"
  sha256 "b8e7f89219e04a2b130d9d506b79265e9981b065ad32652a912211a6057428df"

  bottle do
    cellar :any
    sha1 "f3a198aa80f7868c204101ee3bb4266135acba47" => :mavericks
    sha1 "41d45fc6810d9bd2fac6e5f8b752273dd46f1ac6" => :mountain_lion
    sha1 "3a0073569934c6d4cf831619842001e2e394679c" => :lion
  end

  def install
    ENV.deparallelize

    system "./configure", "--prefix=#{prefix}",
                          "--mandir=#{man}"

    inreplace "Makefile" do |s|
      s.gsub! /[$][(]CP.*BIBCLEAN.*bindir.*BIBCLEAN[)]/,
              "mkdir -p $(bindir) && $(CP) $(BIBCLEAN) $(bindir)/$(BIBCLEAN)"
      s.gsub! /[$][(]CP.*bibclean.*mandir.*bibclean.*manext[)]/,
              "mkdir -p $(mandir) && $(CP) bibclean.man $(mandir)/bibclean.$(manext)"

      s.gsub! /mandir.*prefix.*man.*man1/, "mandir = $(prefix)/share/man/man1"

      s.gsub! /install-ini.*uninstall-ini/,
              "install-ini:  uninstall-ini\n\tmkdir -p #{share}/bibclean"
      s.gsub! /[$][(]bindir[)].*bibcleanrc/,
              "#{share}/bibclean/.bibcleanrc"
      s.gsub! /[$][(]bindir[)].*bibclean.key/,
              "#{share}/bibclean/.bibclean.key"
      s.gsub! /[$][(]bindir[)].*bibclean.isbn/,
              "#{share}/bibclean/.bibclean.isbn"
    end

    system "make", "all"
    system "make", "check"
    system "make", "install"

    ENV.prepend_path "PATH", share+"bibclean"
    bin.env_script_all_files(share+"bibclean", :PATH => ENV["PATH"])
  end

  test do
    (testpath+"test.bib").write <<-EOS.undent
      @article{small,
      author = {Test, T.},
      title = {Test},
      journal = {Test},
      year = 2014,
      note = {test},
      }
    EOS

    system "#{bin}/bibclean", "test.bib"
  end
end
