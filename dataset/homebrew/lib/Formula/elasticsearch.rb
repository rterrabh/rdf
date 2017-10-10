class Elasticsearch < Formula
  desc "Distributed real-time search & analytics engine for the cloud"
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.1.tar.gz"
  sha256 "86a0c20eea6ef55b14345bff5adf896e6332437b19180c4582a346394abde019"

  head do
    url "https://github.com/elasticsearch/elasticsearch.git"
    depends_on "maven" => :build
  end

  depends_on :java => "1.7+"

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end

  def install
    if build.head?
      system "mvn", "clean", "package", "-DskipTests"
      system "tar", "--strip", "1", "-xzf", "target/releases/elasticsearch-*.tar.gz"
    end

    rm_f Dir["bin/*.bat"]
    rm_f Dir["bin/*.exe"]

    libexec.install Dir["lib/*.jar"]
    (libexec/"sigar").install Dir["lib/sigar/*.{jar,dylib}"]

    prefix.install Dir["*"]

    rm_f Dir["#{lib}/sigar/*"]
    if build.head?
      rm_rf "#{prefix}/pom.xml"
      rm_rf "#{prefix}/src/"
      rm_rf "#{prefix}/target/"
    end

    inreplace "#{prefix}/config/elasticsearch.yml" do |s|
      s.gsub!(/#\s*cluster\.name\: elasticsearch/, "cluster.name: #{cluster_name}")

      s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/elasticsearch/")
      s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/elasticsearch/")
      s.sub!(%r{#\s*path\.plugins: /path/to.+$}, "path.plugins: #{var}/lib/elasticsearch/plugins")

      s.gsub!(/#\s*network\.host\: [^\n]+/, "network.host: 127.0.0.1")
    end

    inreplace "#{bin}/elasticsearch.in.sh" do |s|
      s.sub!(%r{#\!/bin/sh\n}, "#!/bin/sh\n\nES_HOME=#{prefix}")
      s.gsub!(%r{ES_HOME/lib/}, "ES_HOME/libexec/")
    end

    inreplace "#{bin}/plugin" do |s|
      s.sub!(/SCRIPT="\$0"/, %(SCRIPT="$0"\nES_CLASSPATH=#{libexec}))
      s.gsub!(%r{\$ES_HOME/lib/}, "$ES_CLASSPATH/")
    end

    (etc/"elasticsearch").install Dir[prefix/"config/*"]
    (prefix/"config").rmtree
  end

  def post_install
    (var/"elasticsearch/#{cluster_name}").mkpath
    (var/"log/elasticsearch").mkpath
    (var/"lib/elasticsearch/plugins").mkpath
    ln_s etc/"elasticsearch", prefix/"config"
  end

  def caveats; <<-EOS.undent
    Data:    #{var}/elasticsearch/#{cluster_name}/
    Logs:    #{var}/log/elasticsearch/#{cluster_name}.log
    Plugins: #{var}/lib/elasticsearch/plugins/
    Config:  #{etc}/elasticsearch/
    EOS
  end

  plist_options :manual => "elasticsearch --config=#{HOMEBREW_PREFIX}/opt/elasticsearch/config/elasticsearch.yml"

  def plist; <<-EOS.undent
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <true/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{HOMEBREW_PREFIX}/bin/elasticsearch</string>
            <string>--config=#{etc}/elasticsearch/elasticsearch.yml</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
            <key>ES_JAVA_OPTS</key>
            <string>-Xss200000</string>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}</string>
          <key>StandardErrorPath</key>
          <string>/dev/null</string>
          <key>StandardOutPath</key>
          <string>/dev/null</string>
        </dict>
      </plist>
    EOS
  end

  test do
    system "#{bin}/plugin", "--list"
  end
end
