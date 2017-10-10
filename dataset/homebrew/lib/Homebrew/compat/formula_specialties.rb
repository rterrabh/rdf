
class ScriptFileFormula < Formula
  def install
    bin.install Dir["*"]
  end
end

class GithubGistFormula < ScriptFileFormula
  def self.url(val)
    super
    version File.basename(File.dirname(val))[0, 6]
  end
end

class AmazonWebServicesFormula < Formula
  def install
    rm Dir["bin/*.cmd"] # Remove Windows versions
    libexec.install Dir["*"]
    bin.install_symlink Dir["#{libexec}/bin/*"] - ["#{libexec}/bin/service"]
  end
  alias_method :standard_install, :install

  def standard_instructions(home_name, home_value = libexec)
    <<-EOS.undent
      Before you can use these tools you must export some variables to your $SHELL.

      To export the needed variables, add them to your dotfiles.
       * On Bash, add them to `~/.bash_profile`.
       * On Zsh, add them to `~/.zprofile` instead.

      export JAVA_HOME="$(/usr/libexec/java_home)"
      export AWS_ACCESS_KEY="<Your AWS Access ID>"
      export AWS_SECRET_KEY="<Your AWS Secret Key>"
      export #{home_name}="#{home_value}"
    EOS
  end
end
