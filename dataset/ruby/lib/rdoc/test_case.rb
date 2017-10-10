require 'rubygems'

begin
  gem 'minitest', '~> 4.0' unless defined?(Test::Unit)
rescue NoMethodError, Gem::LoadError
end

require 'minitest/autorun'
require 'minitest/benchmark' if ENV['BENCHMARK']

require 'fileutils'
require 'pp'
require 'tempfile'
require 'tmpdir'
require 'stringio'

require 'rdoc'


class RDoc::TestCase < MiniTest::Unit::TestCase


  def setup
    super

    @top_level = nil

    @have_encoding = Object.const_defined? :Encoding

    @RM = RDoc::Markup

    RDoc::Markup::PreProcess.reset

    @pwd = Dir.pwd

    @store = RDoc::Store.new

    @rdoc = RDoc::RDoc.new
    @rdoc.store = @store
    @rdoc.options = RDoc::Options.new

    g = Object.new
    def g.class_dir() end
    def g.file_dir() end
    @rdoc.generator = g
  end


  def assert_file path
    assert File.file?(path), "#{path} is not a file"
  end


  def assert_directory path
    assert File.directory?(path), "#{path} is not a directory"
  end


  def refute_file path
    refute File.exist?(path), "#{path} exists"
  end


  def blank_line
    @RM::BlankLine.new
  end


  def block *contents
    @RM::BlockQuote.new(*contents)
  end


  def comment text, top_level = @top_level
    RDoc::Comment.new text, top_level
  end


  def doc *contents
    @RM::Document.new(*contents)
  end


  def hard_break
    @RM::HardBreak.new
  end


  def head level, text
    @RM::Heading.new level, text
  end


  def item label = nil, *parts
    @RM::ListItem.new label, *parts
  end


  def list type = nil, *items
    @RM::List.new type, *items
  end


  def mu_pp obj # :nodoc:
    s = ''
    s = PP.pp obj, s
    s = s.force_encoding Encoding.default_external if defined? Encoding
    s.chomp
  end


  def para *a
    @RM::Paragraph.new(*a)
  end


  def rule weight
    @RM::Rule.new weight
  end


  def raw *contents
    @RM::Raw.new(*contents)
  end


  def temp_dir
    skip "No Dir::mktmpdir, upgrade your ruby" unless Dir.respond_to? :mktmpdir

    Dir.mktmpdir do |temp_dir|
      Dir.chdir temp_dir do
        yield temp_dir
      end
    end
  end


  def verb *parts
    @RM::Verbatim.new(*parts)
  end


  def verbose_capture_io
    capture_io do
      begin
        orig_verbose = $VERBOSE
        $VERBOSE = true
        yield
      ensure
        $VERBOSE = orig_verbose
      end
    end
  end
end

$LOAD_PATH.each do |load_path|
  break if load_path[0] == ?/
  load_path.replace File.expand_path load_path
end if RUBY_VERSION < '1.9'

