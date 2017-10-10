def cache
  if ENV["HOMEBREW_CACHE"]
    Pathname.new(ENV["HOMEBREW_CACHE"]).expand_path
  else
    home_cache = Pathname.new("~/Library/Caches/Homebrew").expand_path
    if home_cache.directory? && home_cache.writable_real?
      home_cache
    else
      Pathname.new("/Library/Caches/Homebrew").extend Module.new {
        def mkpath
          unless exist?
            super
            chmod 0775
          end
        end
      }
    end
  end
end

HOMEBREW_CACHE = cache
undef cache

HOMEBREW_CACHE_FORMULA = HOMEBREW_CACHE+"Formula"

unless defined? HOMEBREW_BREW_FILE
  HOMEBREW_BREW_FILE = ENV["HOMEBREW_BREW_FILE"] || which("brew").to_s
end

HOMEBREW_PREFIX = Pathname.new(HOMEBREW_BREW_FILE).dirname.parent

HOMEBREW_REPOSITORY = Pathname.new(HOMEBREW_BREW_FILE).realpath.dirname.parent

HOMEBREW_LIBRARY = HOMEBREW_REPOSITORY/"Library"
HOMEBREW_CONTRIB = HOMEBREW_REPOSITORY/"Library/Contributions"

HOMEBREW_CELLAR = if (HOMEBREW_PREFIX+"Cellar").exist?
  HOMEBREW_PREFIX+"Cellar"
else
  HOMEBREW_REPOSITORY+"Cellar"
end

HOMEBREW_LOGS = Pathname.new(ENV["HOMEBREW_LOGS"] || "~/Library/Logs/Homebrew/").expand_path

HOMEBREW_TEMP = Pathname.new(ENV.fetch("HOMEBREW_TEMP", "/tmp"))

unless defined? HOMEBREW_LIBRARY_PATH
  HOMEBREW_LIBRARY_PATH = Pathname.new(__FILE__).realpath.parent.join("Homebrew")
end

HOMEBREW_LOAD_PATH = HOMEBREW_LIBRARY_PATH
