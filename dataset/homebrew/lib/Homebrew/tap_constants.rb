HOMEBREW_TAP_ARGS_REGEX = %r{^([\w-]+)/(homebrew-)?([\w-]+)$}
HOMEBREW_TAP_FORMULA_REGEX = %r{^([\w-]+)/([\w-]+)/([\w+-.]+)$}
HOMEBREW_CORE_FORMULA_REGEX = %r{^homebrew/homebrew/([\w+-.]+)$}i
HOMEBREW_TAP_DIR_REGEX = %r{#{Regexp.escape(HOMEBREW_LIBRARY.to_s)}/Taps/([\w-]+)/([\w-]+)}
HOMEBREW_TAP_PATH_REGEX = Regexp.new(HOMEBREW_TAP_DIR_REGEX.source + %r{/(.*)}.source)
HOMEBREW_CASK_TAP_FORMULA_REGEX = %r{^(Caskroom)/(cask)/([\w+-.]+)$}
