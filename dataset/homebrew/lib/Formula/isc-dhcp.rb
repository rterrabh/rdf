class IscDhcp < Formula
  desc "Production-grade DHCP solution"
  homepage "http://www.isc.org/software/dhcp"
  url "http://ftp.isc.org/isc/dhcp/4.3.0/dhcp-4.3.0.tar.gz"
  sha256 "a7b6517d5cf32c5e49d2323a63de00efe5391df7cb0045dfa0ec8f6ee46ebe8a"

  def install
    dhcpd_dir = var+"dhcpd"

    path_opts = {
      "_PATH_DHCPD_CONF"    => etc+"dhcpd.conf",
      "_PATH_DHCLIENT_CONF" => etc+"dhclient.conf",
      "_PATH_DHCPD_DB"      => dhcpd_dir+"dhcpd.leases",
      "_PATH_DHCPD6_DB"     => dhcpd_dir+"dhcpd6.leases",
      "_PATH_DHCLIENT_DB"   => dhcpd_dir+"dhclient.leases",
      "_PATH_DHCLIENT6_DB"  => dhcpd_dir+"dhclient6.leases",
      "_PATH_DHCPD_PID"     => dhcpd_dir+"dhcpd.pid",
      "_PATH_DHCPD6_PID"    => dhcpd_dir+"dhcpd6.pid",
      "_PATH_DHCLIENT_PID"  => dhcpd_dir+"dhclient.pid",
      "_PATH_DHCLIENT6_PID" => dhcpd_dir+"dhclient6.pid",
      "_PATH_DHCRELAY_PID"  => dhcpd_dir+"dhcrelay.pid",
      "_PATH_DHCRELAY6_PID" => dhcpd_dir+"dhcrelay6.pid"
    }

    path_opts.each do |symbol, path|
      ENV.append "CFLAGS", "-D#{symbol}='\"#{path}\"'"
    end

    if MacOS.version >= :lion
      ENV.append "CFLAGS", "-D__APPLE_USE_RFC_3542"
    end

    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--localstatedir=#{dhcpd_dir}"

    ENV.deparallelize { system "make", "-C", "bind" }

    inreplace "Makefile", "SUBDIRS = bind", "SUBDIRS = "
    system "make"
    system "make", "install"

    Dir.open("#{prefix}/etc") do |dir|
      dir.each do |f|
        file = "#{dir.path}/#{f}"
        File.rename(file, "#{file}.sample") if File.file?(file)
      end
    end

    dhcpd_dir.mkpath
    %w[dhcpd dhcpd6 dhclient dhclient6].each do |f|
      file = "#{dhcpd_dir}/#{f}.leases"
      File.new(file, File::CREAT|File::RDONLY).close
    end

    (prefix+"homebrew.mxcl.dhcpd6.plist").write plist_dhcpd6
    (prefix+"homebrew.mxcl.dhcpd6.plist").chmod 0644
  end

  def caveats; <<-EOS.undent
    This install of dhcpd expects config files to be in #{etc}.
    All state files (leases and pids) are stored in #{var}/dhcpd.

    Dhcpd needs to run as root since it listens on privileged ports.

    There are two plists because a single dhcpd process may do either
    DHCPv4 or DHCPv6 but not both. Use one or both as needed.

    Note that you must create the appropriate config files before starting
    the services or dhcpd will refuse to run.
      DHCPv4: #{etc}/dhcpd.conf
      DHCPv6: #{etc}/dhcpd6.conf

    Sample config files may be found in #{etc}.
    EOS
  end

  plist_options :startup => true

  def plist
    <<-EOS.undent
    <?xml version='1.0' encoding='UTF-8'?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
                    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version='1.0'>
    <dict>
    <key>Label</key><string>#{plist_name}</string>
    <key>ProgramArguments</key>
      <array>
        <string>#{opt_sbin}/dhcpd</string>
        <string>-f</string>
      </array>
    <key>Disabled</key><false/>
    <key>KeepAlive</key><true/>
    <key>RunAtLoad</key><true/>
    <key>LowPriorityIO</key><true/>
    </dict>
    </plist>
    EOS
  end

  def plist_dhcpd6
    <<-EOS.undent
    <?xml version='1.0' encoding='UTF-8'?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
                    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version='1.0'>
    <dict>
    <key>Label</key><string>#{plist_name}</string>
    <key>ProgramArguments</key>
      <array>
        <string>#{opt_sbin}/dhcpd</string>
        <string>-f</string>
        <string>-6</string>
        <string>-cf</string>
        <string>#{etc}/dhcpd6.conf</string>
      </array>
    <key>Disabled</key><false/>
    <key>KeepAlive</key><true/>
    <key>RunAtLoad</key><true/>
    <key>LowPriorityIO</key><true/>
    </dict>
    </plist>
    EOS
  end
end
