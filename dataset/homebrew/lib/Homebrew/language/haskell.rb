module Language
  module Haskell
    module Cabal
      module ClassMethods
        def setup_ghc_compilers
          fails_with(:clang) if MacOS.version <= :lion
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      def cabal_sandbox
        pwd = Pathname.pwd
        home = ENV["HOME"]
        ENV["HOME"] = pwd

        cabal_version = `cabal --version`[/[0-9.]+/].split(".").collect(&:to_i)
        if (cabal_version <=> [1, 20]) > -1
          system "cabal", "sandbox", "init"
          cabal_sandbox_bin = pwd/".cabal-sandbox/bin"
        else
          cabal_sandbox_bin = pwd/".cabal/bin"
        end
        mkdir_p cabal_sandbox_bin
        path = ENV["PATH"]
        ENV.prepend_path "PATH", cabal_sandbox_bin
        system "cabal", "update"
        yield
        if (cabal_version <=> [1, 20]) > -1
          system "cabal", "sandbox", "delete"
        end
        ENV["HOME"] = home
        ENV["PATH"] = path
      end

      def cabal_install(*opts)
        system "cabal", "install", "--jobs=#{ENV.make_jobs}", *opts
      end

      def cabal_install_tools(*opts)
        opts.each { |t| cabal_install t }
        rm_rf Dir[".cabal*/*packages.conf.d/"]
      end

      def cabal_clean_lib
        rm_rf lib
      end

      def install_cabal_package(args = [])
        cabal_sandbox do
          cabal_install "--only-dependencies", *args
          cabal_install "--prefix=#{prefix}", *args
        end
        cabal_clean_lib
      end
    end
  end
end
