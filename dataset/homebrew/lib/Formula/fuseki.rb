class Fuseki < Formula
  desc "SPARQL server"
  homepage "https://jena.apache.org/documentation/serving_data/"
  url "https://archive.apache.org/dist/jena/binaries/jena-fuseki1-1.1.2-distribution.tar.gz"
  version "1.1.2"
  sha256 "78bd92b4e32f9e918d89946d11aed9789416f4058b127af60b251b4a8636b5f0"

  def install
    rm_f "fuseki-server.bat"

    rm "fuseki"

    inreplace "fuseki-server" do |s|
      s.gsub! /export FUSEKI_HOME=.+/,
              %(export FUSEKI_HOME="#{libexec}")
    end

    libexec.install "fuseki-server"
    bins = ["s-delete", "s-get", "s-head", "s-post", "s-put", "s-query", "s-update", "s-update-form"]
    chmod 0755, bins
    libexec.install bins
    bin.install_symlink Dir["#{libexec}/*"]
    libexec.install "fuseki-server.jar", "pages"

    etc.install "config.ttl" => "fuseki.ttl"

    (var/"fuseki").mkpath
    (var/"log/fuseki").mkpath

    prefix.install "config-examples.ttl", "config-inf-tdb.ttl", "config-tdb-text.ttl", "config-tdb.ttl"

    prefix.install "Data"

    prefix.install "LICENSE", "NOTICE", "ReleaseNotes.txt"
  end

  def caveats; <<-EOS.undent
    Quick-start guide:

    * See the Fuseki documentation for instructions on using an in-memory database:
      http://jena.apache.org/documentation/serving_data/#fuseki-server-starting-with-an-empty-dataset

    * Running from the LaunchAgent is different the standard configuration and
      uses traditional Unix paths: please inspect the settings here first:

    * NOTE: Fuseki uses 1) log4j.configuration if defined, 2) 'log4j.properties' file if exists,
      or built-in configuration. See also:
      https://issues.apache.org/jira/browse/JENA-536
    EOS
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <false/>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/fuseki-server</string>
          <string>--config</string>
          <string>/usr/local/etc/fuseki.ttl</string>
        </array>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
      </dict>
    </plist>
    EOS
  end

  test do
    system "#{bin}/fuseki-server", "--version"
  end
end
