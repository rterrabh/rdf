class Aeskeyfind < Formula
  desc "Program for automatic key-finding"
  homepage "https://citp.princeton.edu/research/memory/code/"
  url "https://citp.princeton.edu/memory-content/src/aeskeyfind-1.0.tar.gz"
  sha256 "1417e5c1b61e86bb9527db1f5bee1995a0eea82475db3cbc880e04bf706083e4"

  bottle do
    cellar :any
    sha1 "ae159914bc1563e9c8590bafd698fe7bec3d84b5" => :yosemite
    sha1 "ad2ec5824cc627e30699eaaa759e778e18c549be" => :mavericks
    sha1 "f84ccc33df3d7627f91d8088d3fbbe1e2fd48d05" => :mountain_lion
  end

  def install
    system "make"
    bin.install "aeskeyfind"
  end

  test do
    test_key = "30e2b369b65d6d36413f81c78aca6381a97f7e8918482838b7b55fd86839b149"
    test_data = [
      0xA7, 0xFF, 0xA3, 0x4A, 0x2E, 0x26, 0x8D, 0xBA, 0xAF, 0xA7, 0xB5, 0x71, 0x48, 0x49, 0xF9, 0x99,
      0xA4, 0x89, 0xFC, 0xAB, 0x6A, 0x49, 0x57, 0xDD, 0xFE, 0xCD, 0xDE, 0x48, 0x90, 0xDA, 0x00, 0xFB,
      0x7D, 0xFB, 0xE4, 0xD8, 0x21, 0x51, 0xCF, 0xB2, 0x57, 0x4E, 0x76, 0x2C, 0x21, 0x7A, 0x6C, 0x1B,
      0x4A, 0xF0, 0xE4, 0x9F, 0x6E, 0x51, 0x26, 0x17, 0xB1, 0x9C, 0x2B, 0xED, 0xE5, 0xB6, 0x23, 0x34,
      0x66, 0x04, 0x16, 0x54, 0x00, 0x2D, 0xEB, 0xB2, 0x95, 0x1A, 0xD7, 0x12, 0x92, 0x32, 0xC0, 0x3F,
      0x35, 0xD6, 0xB1, 0xA4, 0xA2, 0xC4, 0x84, 0xC8, 0x5A, 0x04, 0xC3, 0x3D, 0x17, 0x53, 0xAB, 0x8B,
      0xB7, 0xC7, 0x44, 0x59, 0x3C, 0x24, 0x11, 0xD3, 0x47, 0x01, 0x44, 0x01, 0x79, 0xEA, 0xA3, 0x7F,
      0x2D, 0xB7, 0x2E, 0x3B, 0x86, 0xAF, 0xC6, 0x90, 0xE5, 0xEE, 0x4F, 0xF2, 0x5A, 0xF2, 0x67, 0xEF,
      0xE9, 0x30, 0x08, 0xA5, 0x69, 0x37, 0xB5, 0x8D, 0x94, 0xEC, 0xAB, 0x51, 0xA6, 0x9D, 0xD3, 0xD1,
      0x43, 0x17, 0xD0, 0xC9, 0x2F, 0x73, 0x62, 0x9B, 0x73, 0x9E, 0xE3, 0xE1, 0xD6, 0x70, 0x50, 0xA4,
      0xC0, 0x9B, 0xC6, 0x20, 0xB9, 0x42, 0xAF, 0x8D, 0xE1, 0x99, 0x7F, 0x4D, 0xA4, 0x93, 0xE4, 0x41,
      0xFA, 0x2F, 0x51, 0x63, 0xE3, 0x21, 0xE4, 0xCC, 0x13, 0xA3, 0x4D, 0x6F, 0x93, 0xAA, 0xC2, 0x04,
      0xD9, 0x7F, 0x70, 0x6D, 0x5E, 0x86, 0xD4, 0x28, 0x71, 0x38, 0x2F, 0xB7, 0xB8, 0xA1, 0x2F, 0x7C,
      0x27, 0x18, 0xD1, 0x9A, 0x0B, 0xC6, 0x44, 0x13, 0x5E, 0xA1, 0xC0, 0x4F, 0x31, 0x80, 0xDA, 0x12,
      0x8F, 0x84, 0xC6, 0xDD, 0x42, 0x6A, 0xD5, 0xD9, 0x6C, 0x8D, 0x3C, 0x7D, 0xAD, 0xDD, 0x92, 0x54,
      0xE8, 0xFA, 0x35, 0x9C, 0x9D, 0xC5, 0xE1, 0xD8, 0x04, 0xA8, 0xA1, 0xBA, 0x85, 0x6D, 0x54, 0xE9,
      0x30, 0x46, 0x08, 0x25, 0xC4, 0xD3, 0x01, 0x7A, 0x5B, 0x63, 0xF9, 0x32, 0xD3, 0x7E, 0x91, 0x49,
      0xA9, 0x52, 0x90, 0xB0, 0x36, 0x71, 0xF2, 0x38, 0x06, 0xB6, 0xB3, 0xBD, 0x5C, 0x81, 0x57, 0xAB,
      0xD1, 0x1D, 0x3E, 0x1C, 0x3A, 0x31, 0x22, 0x43, 0x20, 0xB1, 0xEC, 0xCB, 0xF2, 0x09, 0x37, 0xFD,
      0xCA, 0xC1, 0xDA, 0x48, 0x2B, 0x66, 0x9B, 0xFF, 0x48, 0xA4, 0x75, 0xB6, 0x30, 0xE2, 0xB3, 0x69,
      0xB6, 0x5D, 0x6D, 0x36, 0x41, 0x3F, 0x81, 0xC7, 0x8A, 0xCA, 0x63, 0x81, 0xA9, 0x7F, 0x7E, 0x89,
      0x18, 0x48, 0x28, 0x38, 0xB7, 0xB5, 0x5F, 0xD8, 0x68, 0x39, 0xB1, 0x49, 0x23, 0x2A, 0x88, 0x2C,
      0x95, 0x77, 0xE5, 0x1A, 0xD4, 0x48, 0x64, 0xDD, 0x5E, 0x82, 0x07, 0x5C, 0xF1, 0x6C, 0xBB, 0xC3,
      0xE9, 0x24, 0x93, 0xFB, 0x5E, 0x91, 0xCC, 0x23, 0x36, 0xA8, 0x7D, 0x6A, 0xE3, 0xD5, 0x8A, 0x29,
      0x76, 0xA2, 0x6F, 0x33, 0xA2, 0xEA, 0x0B, 0xEE, 0xFC, 0x68, 0x0C, 0xB2, 0x41, 0x29, 0x45, 0xF4,
      0xA8, 0x0D, 0xD6, 0x0F, 0xF6, 0x9C, 0x1A, 0x2C, 0xC0, 0x34, 0x67, 0x46, 0xFF, 0x50, 0xD0, 0x93,
      0x89, 0xF2, 0xBF, 0xA0, 0x2B, 0x18, 0xB4, 0x4E, 0xD7, 0x70, 0xB8, 0xFC, 0x4F, 0x78, 0x29, 0x44,
      0xE7, 0x75, 0xFF, 0x4B, 0x11, 0xE9, 0xE5, 0x67, 0xD1, 0xDD, 0x82, 0x21, 0x36, 0x43, 0x2D, 0xAD,
      0xBF, 0xB1, 0x92, 0x0D, 0x94, 0xA9, 0x26, 0x43, 0x43, 0xD9, 0x9E, 0xBF, 0x55, 0x4D, 0x22, 0x4C,
      0xB2, 0x38, 0xDD, 0x07, 0xA3, 0xD1, 0x38, 0x60, 0x72, 0x0C, 0xBA, 0x41, 0xD8, 0xB7, 0xAE, 0xED,
      0x67, 0x06, 0x3C, 0xE0, 0xF3, 0xAF, 0x1A, 0xA3, 0xB0, 0x76, 0x84, 0x1C, 0xB2, 0x75, 0x7D, 0xD0,
      0x00, 0x4D, 0xA0, 0xD7, 0xA3, 0x9C, 0x98, 0xB7, 0xD1, 0x90, 0x22, 0xF6, 0x98, 0x24, 0xEC, 0xD3,
      0xFF, 0x22, 0xD0, 0x33, 0x0C, 0x8D, 0xCA, 0x90, 0xBC, 0xFB, 0x4E, 0x8C, 0xD7, 0x7A, 0x52, 0xB4,
      0xD7, 0x37, 0xF2, 0x63, 0x74, 0xAB, 0x6A, 0xD4, 0xA5, 0x3B, 0x48, 0x22, 0x3A, 0x76, 0x7F, 0xD5,
      0xC5, 0x54, 0xAF, 0xE6, 0xC9, 0xD9, 0x65, 0x76, 0x75, 0x22, 0x2B, 0xFA, 0
    ]

    path = testpath/"aeskey.bin"
    path.binwrite(test_data.pack("C*"))
    output = shell_output("#{bin}/aeskeyfind -q #{path}").strip

    assert_equal test_key, output
  end
end
