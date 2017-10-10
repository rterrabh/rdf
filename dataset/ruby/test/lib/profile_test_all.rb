
require 'objspace'

class MiniTest::Unit::TestCase
  alias orig_run run

  file = ENV['RUBY_TEST_ALL_PROFILE']
  file = 'test-all-profile-result' if file == 'true'
  TEST_ALL_PROFILE_OUT = open(file, 'w')
  TEST_ALL_PROFILE_GC_STAT_HASH = {}
  TEST_ALL_PROFILE_BANNER = ['name']
  TEST_ALL_PROFILE_PROCS  = []

  def self.add *name, &b
    TEST_ALL_PROFILE_BANNER.concat name
    TEST_ALL_PROFILE_PROCS << b
  end

  add 'failed?' do |result, tc|
    result << (tc.passed? ? 0 : 1)
  end

  add 'memsize_of_all' do |result, *|
    result << ObjectSpace.memsize_of_all
  end

  add *GC.stat.keys do |result, *|
    GC.stat(TEST_ALL_PROFILE_GC_STAT_HASH)
    result.concat TEST_ALL_PROFILE_GC_STAT_HASH.values
  end

  def self.add_proc_meminfo file, fields
    return unless FileTest.exist?(file)
    regexp = /(#{fields.join("|")}):\s*(\d+) kB/
    add *fields do |result, *|
      text = File.read(file)
      text.scan(regexp){
        result << $2
        ''
      }
    end
  end

  add_proc_meminfo '/proc/meminfo', %w(MemTotal MemFree)
  add_proc_meminfo '/proc/self/status', %w(VmPeak VmSize VmHWM VmRSS)

  if FileTest.exist?('/proc/self/statm')
    add *%w(size resident share text lib data dt) do |result, *|
      result.concat File.read('/proc/self/statm').split(/\s+/)
    end
  end

  def memprofile_test_all_result_result
    result = ["#{self.class}\##{self.__name__.to_s.gsub(/\s+/, '')}"]
    TEST_ALL_PROFILE_PROCS.each{|proc|
      proc.call(result, self)
    }
    result.join("\t")
  end

  def run runner
    result = orig_run(runner)
    TEST_ALL_PROFILE_OUT.puts memprofile_test_all_result_result
    TEST_ALL_PROFILE_OUT.flush
    result
  end

  TEST_ALL_PROFILE_OUT.puts TEST_ALL_PROFILE_BANNER.join("\t")
end
