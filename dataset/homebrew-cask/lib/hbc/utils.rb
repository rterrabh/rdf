module Hbc::Utils; end

require 'yaml'
require 'open3'
require 'stringio'

require 'hbc/utils/tty'

UPDATE_CMD = "brew update && brew upgrade brew-cask && brew cleanup && brew cask cleanup"
ISSUES_URL = "https://github.com/caskroom/homebrew-cask/issues"

Tty = Hbc::Utils::Tty

class Object
  def utf8_inspect
    if not defined?(Encoding)
      self.inspect
    else
      if self.respond_to?(:map)
        self.map do |sub_elt|
          sub_elt.utf8_inspect
        end
      else
        self.inspect.force_encoding('UTF-8').sub(%r{\A"(.*)"\Z}, '\1')
      end
    end
  end
end

class Buffer < StringIO
  def initialize(tty = false)
    super()
    @tty = tty
  end

  def tty?
    @tty
  end
end


def ohai(title, *sput)
  title = Tty.truncate(title) if $stdout.tty? && !Hbc.verbose
  puts "#{Tty.blue.bold}==>#{Tty.reset.bold} #{title}#{Tty.reset}"
  puts sput unless sput.empty?
end

def opoo(warning)
  $stderr.puts "#{Tty.yellow.underline}Warning#{Tty.reset}: #{warning}"
end

def onoe(error)
  $stderr.puts "#{Tty.red.underline}Error#{Tty.reset}: #{error}"
end

def odebug(title, *sput)
  if Hbc.respond_to?(:debug) and Hbc.debug
    width = Tty.width * 4 - 6
    if $stdout.tty? and title.to_s.length > width
      title = title.to_s[0, width - 3] + '...'
    end
    puts "#{Tty.magenta.bold}==>#{Tty.reset.bold} #{title}#{Tty.reset}"
    puts sput unless sput.empty?
  end
end

def puts_columns(items, star_items=[])
  return if items.empty?
  puts Hbc::Utils.stringify_columns(items, star_items)
end

module Hbc::Utils

  def self.which(cmd, path=ENV['PATH'])
    unless File.basename(cmd) == cmd.to_s
      cmd_pn = Pathname(cmd)
      return nil unless cmd_pn.absolute?
      return resolve_executable(cmd_pn)
    end
    path.split(File::PATH_SEPARATOR).each do |elt|
      fq_cmd = Pathname(elt).expand_path.join(cmd)
      resolved = resolve_executable fq_cmd
      return resolved if resolved
    end
    return nil
  end

  def self.resolve_executable(cmd)
    cmd_pn = Pathname(cmd)
    return nil unless cmd_pn.exist?
    return nil unless cmd_pn.executable?
    begin
      cmd_pn = Pathname(cmd_pn.realpath)
    rescue RuntimeError => e
      return nil
    end
    return nil unless cmd_pn.file?
    return cmd_pn
  end

  def self.exec_editor(*args)
    editor = [
              *ENV.values_at('HOMEBREW_EDITOR', 'VISUAL', 'EDITOR'),
              *%w{mate edit vim /usr/bin/vim}.map{ |x| which(x) }
             ].compact.first.to_s
    exec(*editor.split.concat(args))
  end

  def self.stringify_columns items, star_items=[]
    return if items.empty?

    if star_items && star_items.any?
      items = items.map{|item| star_items.include?(item) ? "#{item}*" : item}
    end

    unless $stdout.tty?
      return items.join("\n").concat("\n")
    end

    console_width = `/bin/stty size 2>/dev/null`.chomp.split(' ').last.to_i
    console_width = 80 if console_width <= 0
    longest = items.sort_by { |item| item.length }.last
    optimal_col_width = (console_width.to_f / (longest.length + 2).to_f).floor
    cols = optimal_col_width > 1 ? optimal_col_width : 1
    Open3.popen3('/usr/bin/pr', "-#{cols}", '-t', "-w#{console_width}") do |stdin, stdout, stderr|
      stdin.puts(items)
      stdin.close
      stdout.read
    end
  end

  def self.rmdir_if_possible(dir)
    dirpath = Pathname(dir)
    begin
      dirpath.rmdir
      true
    rescue Errno::ENOTEMPTY
      if (ds_store = dirpath.join('.DS_Store')).exist? and
        dirpath.children.length == 1
        ds_store.unlink
        retry
      else
        false
      end
    rescue Errno::EACCES, Errno::ENOENT
      false
    end
  end

  def self.cabv(dir)
    output = ''
    count = Hbc::SystemCommand.run!('/usr/bin/find',
                                     :args => [dir, *%w[-type f -not -name .DS_Store -print0]],
                                     :print_stderr => false).stdout.count("\000")
    size = Hbc::SystemCommand.run!('/usr/bin/du',
                                    :args => ['-hs', '--', dir],
                                    :print_stderr => false).stdout.split("\t").first.strip
    output << "#{count} files, " if count > 1
    output << size
  end

  def self.file_is_descendant(file, dir)
    file = Pathname.new(file)
    dir  = Pathname.new(dir)
    return false unless file.exist? and dir.exist?
    unless dir.directory?
      onoe "Argument must be a directory: '#{dir}'"
      return false
    end
    unless file.absolute? and dir.absolute?
      onoe "Both arguments must be absolute: '#{file}', '#{dir}'"
      return false
    end
    while file.parent != file
      return true if File.identical?(file, dir)
      file = file.parent
    end
    return false
  end

  def self.error_message_with_suggestions
    <<-EOS.undent
      Most likely, this means you have an outdated version of homebrew-cask.#{
      } Please run:




    EOS
  end

  def self.method_missing_message(method, token, section=nil)
    poo = []
    poo << "Unexpected method '#{method}' called"
    poo << "during #{section}" if section
    poo << "on Cask #{token}."

    opoo(poo.join(' ') + "\n" + error_message_with_suggestions)
  end

  def self.ignore_interrupts(opt = nil)
    std_trap = trap('INT') do
      puts 'One sec, just cleaning up' unless opt == :quietly
    end
    yield
  ensure
    trap('INT', std_trap)
  end

  def self.nowstamp_metadata_path(container_path)
    @timenow ||= Time.now.gmtime
    if container_path.respond_to?(:join)
      precision = 3
      timestamp = @timenow.strftime('%Y%m%d%H%M%S')
      fraction = ("%.#{precision}f" % (@timenow.to_f - @timenow.to_i))[1..-1]
      timestamp.concat(fraction)
      container_path.join(timestamp)
    end
  end
end
