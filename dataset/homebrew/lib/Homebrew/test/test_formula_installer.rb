require "testing_env"
require "formula"
require "compat/formula_specialties"
require "formula_installer"
require "keg"
require "testball"

class InstallTests < Homebrew::TestCase
  def temporary_install(formula)
    refute_predicate formula, :installed?

    installer = FormulaInstaller.new(formula)

    shutup { installer.install }

    keg = Keg.new(formula.prefix)

    assert_predicate formula, :installed?

    begin
      yield formula
    ensure
      keg.unlink
      keg.uninstall
      formula.clear_cache
      formula.logs.rmtree if formula.logs.directory?
    end

    refute_predicate keg, :exist?
    refute_predicate formula, :installed?
  end

  def test_a_basic_install
    temporary_install(Testball.new) do |f|
      assert_predicate f.bin, :directory?
      assert_equal 3, f.bin.children.length

      assert_predicate f.libexec, :directory?
      assert_equal 1, f.libexec.children.length

      refute_predicate f.prefix+"main.c", :exist?

      keg = Keg.new f.prefix
      keg.link

      bin = HOMEBREW_PREFIX+"bin"
      assert_predicate bin, :directory?
      assert_equal 3, bin.children.length
    end
  end
end
