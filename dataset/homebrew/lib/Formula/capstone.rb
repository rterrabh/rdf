class Capstone < Formula
  desc "Multi-platform, multi-architecture disassembly framework"
  homepage "http://capstone-engine.org"
  url "http://capstone-engine.org/download/3.0.4/capstone-3.0.4.tgz"
  sha256 "3e88abdf6899d11897f2e064619edcc731cc8e97e9d4db86495702551bb3ae7f"

  bottle do
    cellar :any
    sha256 "5bbd8f7d9e0ae0d3b23c7d478fdb02476e8cee847577576d543bf98649985975" => :yosemite
    sha256 "0cfd7478b21360ffea1aac61ec64eeae612bce247a681b0205ffd14790f8f7dc" => :mavericks
    sha256 "585042b1452fbeda9efd07da4b8400d56d166afd5e5f1120da20975e41001e88" => :mountain_lion
  end

  def install
    inreplace "make.sh", "export PREFIX=/usr/local", "export PREFIX=#{prefix}"

    ENV["HOMEBREW_CAPSTONE"] = "1"
    system "./make.sh"
    system "./make.sh", "install"

    inreplace lib/"pkgconfig/capstone.pc" do |s|
      s.gsub! "/usr/lib", lib
      s.gsub! "/usr/include/capstone", "#{include}/capstone"
    end
  end

  test do
    (testpath/"test.c").write <<-EOS.undent

      int main()
      {
        csh handle;
        cs_insn *insn;
        size_t count;
        if (cs_open(CS_ARCH_X86, CS_MODE_64, &handle) != CS_ERR_OK)
          return -1;
        count = cs_disasm(handle, CODE, sizeof(CODE)-1, 0x1000, 0, &insn);
        if (count > 0) {
          size_t j;
          for (j = 0; j < count; j++) {
            printf("0x%"PRIx64":\\t%s\\t\\t%s\\n", insn[j].address, insn[j].mnemonic,insn[j].op_str);
          }
          cs_free(insn, count);
        } else
          printf("ERROR: Failed to disassemble given code!\\n");
        cs_close(&handle);
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-L#{lib}", "-lcapstone", "-o", "test"
    system "./test"
  end
end
