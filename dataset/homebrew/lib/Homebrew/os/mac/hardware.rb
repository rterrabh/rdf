require "mach"

module MacCPUs
  OPTIMIZATION_FLAGS = {
    :penryn => "-march=core2 -msse4.1",
    :core2 => "-march=core2",
    :core => "-march=prescott",
    :g3 => "-mcpu=750",
    :g4 => "-mcpu=7400",
    :g4e => "-mcpu=7450",
    :g5 => "-mcpu=970"
  }.freeze
  def optimization_flags
    OPTIMIZATION_FLAGS
  end

  def type
    case sysctl_int("hw.cputype")
    when 7
      :intel
    when 18
      :ppc
    else
      :dunno
    end
  end

  def family
    if intel?
      case sysctl_int("hw.cpufamily")
      when 0x73d67300 # Yonah: Core Solo/Duo
        :core
      when 0x426f69ef # Merom: Core 2 Duo
        :core2
      when 0x78ea4fbc # Penryn
        :penryn
      when 0x6b5a4cd2 # Nehalem
        :nehalem
      when 0x573B5EEC # Arrandale
        :arrandale
      when 0x5490B78C # Sandy Bridge
        :sandybridge
      when 0x1F65E835 # Ivy Bridge
        :ivybridge
      when 0x10B282DC # Haswell
        :haswell
      when 0x582ed09c # Broadwell
        :broadwell
      else
        :dunno
      end
    elsif ppc?
      case sysctl_int("hw.cpusubtype")
      when 9
        :g3  # PowerPC 750
      when 10
        :g4  # PowerPC 7400
      when 11
        :g4e # PowerPC 7450
      when 100
        MacOS.prefer_64_bit? ? :g5_64 : :g5 # PowerPC 970
      else
        :dunno
      end
    end
  end

  def extmodel
    sysctl_int("machdep.cpu.extmodel")
  end

  def cores
    sysctl_int("hw.ncpu")
  end

  def bits
    sysctl_bool("hw.cpu64bit_capable") ? 64 : 32
  end

  def arch_32_bit
    intel? ? :i386 : :ppc
  end

  def arch_64_bit
    intel? ? :x86_64 : :ppc64
  end

  def universal_archs
    if MacOS.version <= :leopard && !MacOS.prefer_64_bit?
      [arch_32_bit].extend ArchitectureListExtension
    else
      [arch_32_bit, arch_64_bit].extend ArchitectureListExtension
    end
  end

  def features
    @features ||= sysctl_n(
      "machdep.cpu.features",
      "machdep.cpu.extfeatures",
      "machdep.cpu.leaf7_features"
    ).split(" ").map { |s| s.downcase.to_sym }
  end

  def aes?
    sysctl_bool("hw.optional.aes")
  end

  def altivec?
    sysctl_bool("hw.optional.altivec")
  end

  def avx?
    sysctl_bool("hw.optional.avx1_0")
  end

  def avx2?
    sysctl_bool("hw.optional.avx2_0")
  end

  def sse3?
    sysctl_bool("hw.optional.sse3")
  end

  def ssse3?
    sysctl_bool("hw.optional.supplementalsse3")
  end

  def sse4?
    sysctl_bool("hw.optional.sse4_1")
  end

  def sse4_2?
    sysctl_bool("hw.optional.sse4_2")
  end

  private

  def sysctl_bool(key)
    sysctl_int(key) == 1
  end

  def sysctl_int(key)
    sysctl_n(key).to_i
  end

  def sysctl_n(*keys)
    (@properties ||= {}).fetch(keys) do
      @properties[keys] = Utils.popen_read("/usr/sbin/sysctl", "-n", *keys)
    end
  end
end
