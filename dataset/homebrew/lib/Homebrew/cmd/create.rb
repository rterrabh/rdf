require "formula"
require "blacklist"
require "digest"
require "erb"

module Homebrew
  def create
    if ARGV.include? "--macports"
      exec_browser "https://www.macports.org/ports.php?by=name&substr=#{ARGV.next}"
    elsif ARGV.include? "--fink"
      exec_browser "http://pdb.finkproject.org/pdb/browse.php?summary=#{ARGV.next}"
    end

    raise UsageError if ARGV.named.empty?

    HOMEBREW_CACHE.mkpath

    url = ARGV.named.first # Pull the first (and only) url from ARGV

    version = ARGV.next if ARGV.include? "--set-version"
    name = ARGV.next if ARGV.include? "--set-name"

    fc = FormulaCreator.new
    fc.name = name
    fc.version = version
    fc.url = url

    fc.mode = if ARGV.include? "--cmake"
      :cmake
    elsif ARGV.include? "--autotools"
      :autotools
    end

    if fc.name.nil? || fc.name.strip.empty?
      stem = Pathname.new(url).stem
      print "Formula name [#{stem}]: "
      fc.name = __gets || stem
      fc.path = Formulary.path(fc.name)
    end

    unless ARGV.force?
      if msg = blacklisted?(fc.name)
        raise "#{fc.name} is blacklisted for creation.\n#{msg}\nIf you really want to create this formula use --force."
      end

      if Formula.aliases.include? fc.name
        realname = Formulary.canonical_name(fc.name)
        raise <<-EOS.undent
          The formula #{realname} is already aliased to #{fc.name}
          Please check that you are not creating a duplicate.
          To force creation use --force.
          EOS
      end
    end

    fc.generate!

    puts "Please `brew audit --strict #{fc.name}` before submitting, thanks."
    exec_editor fc.path
  end

  def __gets
    gots = $stdin.gets.chomp
    if gots.empty? then nil else gots end
  end
end

class FormulaCreator
  attr_reader :url, :sha256
  attr_accessor :name, :version, :path, :mode

  def url=(url)
    @url = url
    path = Pathname.new(url)
    if @name.nil?
      %r{github.com/\S+/(\S+)/archive/}.match url
      @name ||= $1
      /(.*?)[-_.]?#{path.version}/.match path.basename
      @name ||= $1
      @path = Formulary.path @name unless @name.nil?
    else
      @path = Formulary.path name
    end
    if @version
      @version = Version.new(@version)
    else
      @version = Pathname.new(url).version
    end
  end

  def fetch?
    !ARGV.include?("--no-fetch")
  end

  def generate!
    raise "#{path} already exists" if path.exist?

    if version.nil?
      opoo "Version cannot be determined from URL."
      puts "You'll need to add an explicit 'version' to the formula."
    end

    if fetch? && version
      r = Resource.new
      r.url(url)
      r.version(version)
      r.owner = self
      @sha256 = r.fetch.sha256 if r.download_strategy == CurlDownloadStrategy
    end

    path.write ERB.new(template, nil, ">").result(binding)
  end

  def template; <<-EOS.undent

    class #{Formulary.class_s(name)} < Formula
      desc ""
      homepage ""
      url "#{url}"
    <% unless version.nil? or version.detected_from_url? %>
      version "#{version}"
    <% end %>
      sha256 "#{sha256}"

    <% if mode == :cmake %>
      depends_on "cmake" => :build
    <% elsif mode.nil? %>
    <% end %>
      depends_on :x11 # if your formula requires any X11/XQuartz components

      def install

    <% if mode == :cmake %>
        system "cmake", ".", *std_cmake_args
    <% elsif mode == :autotools %>
        system "./configure", "--disable-debug",
                              "--disable-dependency-tracking",
                              "--disable-silent-rules",
                              "--prefix=\#{prefix}"
    <% else %>
        system "./configure", "--disable-debug",
                              "--disable-dependency-tracking",
                              "--disable-silent-rules",
                              "--prefix=\#{prefix}"
    <% end %>
        system "make", "install" # if this fails, try separate make/make install steps
      end

      test do
        system "false"
      end
    end
    EOS
  end
end
