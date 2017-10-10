module Homebrew
  def cat

    raise FormulaUnspecifiedError if ARGV.named.empty?
    cd HOMEBREW_REPOSITORY
    exec "cat", ARGV.formulae.first.path, *ARGV.options_only
  end
end
