require "utils/json"

class Tap
  TAP_DIRECTORY = HOMEBREW_LIBRARY/"Taps"

  extend Enumerable

  attr_reader :user

  attr_reader :repo

  attr_reader :name

  attr_reader :path

  def initialize(user, repo)
    @user = user == "homebrew" ? "Homebrew" : user
    @repo = repo
    @name = "#{@user}/#{@repo}".downcase
    @path = TAP_DIRECTORY/"#{@user}/homebrew-#{@repo}".downcase
  end

  def remote
    @remote ||= if installed?
      if git?
        @path.cd do
          Utils.popen_read("git", "config", "--get", "remote.origin.url").chomp
        end
      end
    else
      raise TapUnavailableError, name
    end
  end

  def git?
    (@path/".git").exist?
  end

  def to_s
    name
  end

  def official?
    @user == "Homebrew"
  end

  def private?
    return true if custom_remote?
    GitHub.private_repo?(@user, "homebrew-#{@repo}")
  rescue GitHub::HTTPNotFoundError
    true
  rescue GitHub::Error
    false
  end

  def installed?
    @path.directory?
  end

  def custom_remote?
    return true unless remote
    remote.casecmp("https://github.com/#{@user}/homebrew-#{@repo}") != 0
  end

  def formula_files
    dir = [@path/"Formula", @path/"HomebrewFormula", @path].detect(&:directory?)
    return [] unless dir
    dir.children.select { |p| p.extname == ".rb" }
  end

  def formula_names
    formula_files.map { |f| "#{name}/#{f.basename(".rb")}" }
  end

  def command_files
    Pathname.glob("#{path}/cmd/brew-*").select(&:executable?)
  end

  def pinned_symlink_path
    HOMEBREW_LIBRARY/"PinnedTaps/#{@name}"
  end

  def pinned?
    @pinned ||= pinned_symlink_path.directory?
  end

  def pin
    raise TapUnavailableError, name unless installed?
    raise TapPinStatusError.new(name, true) if pinned?
    pinned_symlink_path.make_relative_symlink(@path)
  end

  def unpin
    raise TapUnavailableError, name unless installed?
    raise TapPinStatusError.new(name, false) unless pinned?
    pinned_symlink_path.delete
    pinned_symlink_path.dirname.rmdir_if_possible
  end

  def to_hash
    hash = {
      "name" => @name,
      "user" => @user,
      "repo" => @repo,
      "path" => @path.to_s,
      "installed" => installed?,
      "official" => official?,
      "formula_names" => formula_names,
      "formula_files" => formula_files.map(&:to_s),
      "command_files" => command_files.map(&:to_s),
      "pinned" => pinned?
    }

    if installed?
      hash["remote"] = remote
      hash["custom_remote"] = custom_remote?
    end

    hash
  end

  def formula_renames
    @formula_renames ||= if (rename_file = path/"formula_renames.json").file?
      Utils::JSON.load(rename_file.read)
    else
      {}
    end
  end

  def self.each
    return unless TAP_DIRECTORY.directory?

    TAP_DIRECTORY.subdirs.each do |user|
      user.subdirs.each do |repo|
        yield new(user.basename.to_s, repo.basename.to_s.sub("homebrew-", ""))
      end
    end
  end

  def self.names
    map(&:name)
  end
end
