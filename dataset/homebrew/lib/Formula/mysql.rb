class Mysql < Formula
  desc "Open source relational database management system"
  homepage "https://dev.mysql.com/doc/refman/5.6/en/"
  url "https://cdn.mysql.com/Downloads/MySQL-5.6/mysql-5.6.26.tar.gz"
  sha256 "b44c6ce5f95172c56c73edfa8b710b39242ec7af0ab182c040208c41866e5070"

  bottle do
    sha256 "fae4e0791575b643c0f7f3c0368a4fdbafb7d00c03f41431fff25dbbfa83b4cc" => :yosemite
    sha256 "954769ebb859807b570bf09268b37e470891cbf2dceebd8ef6c92d8f36baf15d" => :mavericks
    sha256 "b05421d5f0c0b160c605fa6f19986555e485b0504cec77febca74ec4ebd499e1" => :mountain_lion
  end

  depends_on "cmake" => :build
  depends_on "pidof" unless MacOS.version >= :mountain_lion
  depends_on "openssl"

  option :universal
  option "with-tests", "Build with unit tests"
  option "with-embedded", "Build the embedded server"
  option "with-archive-storage-engine", "Compile with the ARCHIVE storage engine enabled"
  option "with-blackhole-storage-engine", "Compile with the BLACKHOLE storage engine enabled"
  option "with-local-infile", "Build with local infile loading support"
  option "with-memcached", "Enable innodb-memcached support"
  option "with-debug", "Build with debug support"

  deprecated_option "enable-local-infile" => "with-local-infile"
  deprecated_option "enable-memcached" => "with-memcached"
  deprecated_option "enable-debug" => "with-debug"

  conflicts_with "mysql-cluster", "mariadb", "percona-server",
    :because => "mysql, mariadb, and percona install the same binaries."
  conflicts_with "mysql-connector-c",
    :because => "both install MySQL client libraries"

  fails_with :llvm do
    build 2326
    cause "https://github.com/Homebrew/homebrew/issues/issue/144"
  end

  def datadir
    var/"mysql"
  end

  def install
    inreplace "cmake/libutils.cmake",
      "COMMAND /usr/bin/libtool -static -o ${TARGET_LOCATION}",
      "COMMAND libtool -static -o ${TARGET_LOCATION}"

    ENV.minimal_optimization

    args = %W[
      .
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_FIND_FRAMEWORK=LAST
      -DCMAKE_VERBOSE_MAKEFILE=ON
      -DMYSQL_DATADIR=#{datadir}
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_MANDIR=share/man
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DWITH_SSL=yes
      -DWITH_SSL=system
      -DDEFAULT_CHARSET=utf8
      -DDEFAULT_COLLATION=utf8_general_ci
      -DSYSCONFDIR=#{etc}
      -DCOMPILATION_COMMENT=Homebrew
      -DWITH_EDITLINE=system
    ]

    if build.with? "tests"
      args << "-DENABLE_DOWNLOADS=ON"
    else
      args << "-DWITH_UNIT_TESTS=OFF"
    end

    args << "-DWITH_EMBEDDED_SERVER=ON" if build.with? "embedded"

    args << "-DWITH_ARCHIVE_STORAGE_ENGINE=1" if build.with? "archive-storage-engine"

    args << "-DWITH_BLACKHOLE_STORAGE_ENGINE=1" if build.with? "blackhole-storage-engine"

    if build.universal?
      ENV.universal_binary
      args << "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.universal_archs.as_cmake_arch_flags}"
    end

    args << "-DENABLED_LOCAL_INFILE=1" if build.with? "local-infile"

    args << "-DWITH_INNODB_MEMCACHED=1" if build.with? "memcached"

    args << "-DWITH_DEBUG=1" if build.with? "debug"

    system "cmake", *args
    system "make"
    system "make", "install"

    rm_rf prefix/"data"

    bin.install_symlink prefix/"scripts/mysql_install_db"

    inreplace "#{prefix}/support-files/mysql.server" do |s|
      s.gsub!(/^(PATH=".*)(")/, "\\1:#{HOMEBREW_PREFIX}/bin\\2")
      s.gsub!(/pidof/, "pgrep") if MacOS.version >= :mountain_lion
    end

    bin.install_symlink prefix/"support-files/mysql.server"

    libexec.install bin/"mysqlaccess"
    libexec.install bin/"mysqlaccess.conf"
  end

  def post_install
    datadir.mkpath
    unless (datadir/"mysql/user.frm").exist?
      ENV["TMPDIR"] = nil
      system bin/"mysql_install_db", "--verbose", "--user=#{ENV["USER"]}",
        "--basedir=#{prefix}", "--datadir=#{datadir}", "--tmpdir=/tmp"
    end
  end

  def caveats; <<-EOS.undent
    A "/etc/my.cnf" from another install may interfere with a Homebrew-built
    server starting up correctly.

    To connect:
        mysql -uroot
    EOS
  end

  plist_options :manual => "mysql.server start"

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
        <string>#{opt_bin}/mysqld_safe</string>
        <string>--bind-address=127.0.0.1</string>
        <string>--datadir=#{datadir}</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>WorkingDirectory</key>
      <string>#{datadir}</string>
    </dict>
    </plist>
    EOS
  end

  test do
    (prefix/"mysql-test").cd do
      system "./mysql-test-run.pl", "status"
    end
  end
end
