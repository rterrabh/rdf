
require 'minitest/unit'

class MiniTest::Unit # :nodoc:
  def run_benchmarks # :nodoc:
    _run_anything :benchmark
  end

  def benchmark_suite_header suite # :nodoc:
    "\n#{suite}\t#{suite.bench_range.join("\t")}"
  end

  class TestCase

    def self.bench_exp min, max, base = 10
      min = (Math.log10(min) / Math.log10(base)).to_i
      max = (Math.log10(max) / Math.log10(base)).to_i

      (min..max).map { |m| base ** m }.to_a
    end


    def self.bench_linear min, max, step = 10
      (min..max).step(step).to_a
    rescue LocalJumpError # 1.8.6
      r = []; (min..max).step(step) { |n| r << n }; r
    end


    def self.benchmark_methods # :nodoc:
      public_instance_methods(true).grep(/^bench_/).map { |m| m.to_s }.sort
    end


    def self.benchmark_suites
      TestCase.test_suites.reject { |s| s.benchmark_methods.empty? }
    end


    def self.bench_range
      bench_exp 1, 10_000
    end


    def assert_performance validation, &work
      range = self.class.bench_range

      io.print "#{__name__}"

      times = []

      range.each do |x|
        GC.start
        t0 = Time.now
        #nodyna <instance_exec-1450> <IEX COMPLEX (block with parameters)>
        instance_exec(x, &work)
        t = Time.now - t0

        io.print "\t%9.6f" % t
        times << t
      end
      io.puts

      validation[range, times]
    end


    def assert_performance_constant threshold = 0.99, &work
      validation = proc do |range, times|
        a, b, rr = fit_linear range, times
        assert_in_delta 0, b, 1 - threshold
        [a, b, rr]
      end

      assert_performance validation, &work
    end


    def assert_performance_exponential threshold = 0.99, &work
      assert_performance validation_for_fit(:exponential, threshold), &work
    end


    def assert_performance_logarithmic threshold = 0.99, &work
      assert_performance validation_for_fit(:logarithmic, threshold), &work
    end


    def assert_performance_linear threshold = 0.99, &work
      assert_performance validation_for_fit(:linear, threshold), &work
    end


    def assert_performance_power threshold = 0.99, &work
      assert_performance validation_for_fit(:power, threshold), &work
    end


    def fit_error xys
      y_bar  = sigma(xys) { |x, y| y } / xys.size.to_f
      ss_tot = sigma(xys) { |x, y| (y    - y_bar) ** 2 }
      ss_err = sigma(xys) { |x, y| (yield(x) - y) ** 2 }

      1 - (ss_err / ss_tot)
    end


    def fit_exponential xs, ys
      n     = xs.size
      xys   = xs.zip(ys)
      sxlny = sigma(xys) { |x,y| x * Math.log(y) }
      slny  = sigma(xys) { |x,y| Math.log(y)     }
      sx2   = sigma(xys) { |x,y| x * x           }
      sx    = sigma xs

      c = n * sx2 - sx ** 2
      a = (slny * sx2 - sx * sxlny) / c
      b = ( n * sxlny - sx * slny ) / c

      return Math.exp(a), b, fit_error(xys) { |x| Math.exp(a + b * x) }
    end


    def fit_logarithmic xs, ys
      n     = xs.size
      xys   = xs.zip(ys)
      slnx2 = sigma(xys) { |x,y| Math.log(x) ** 2 }
      slnx  = sigma(xys) { |x,y| Math.log(x)      }
      sylnx = sigma(xys) { |x,y| y * Math.log(x)  }
      sy    = sigma(xys) { |x,y| y                }

      c = n * slnx2 - slnx ** 2
      b = ( n * sylnx - sy * slnx ) / c
      a = (sy - b * slnx) / n

      return a, b, fit_error(xys) { |x| a + b * Math.log(x) }
    end



    def fit_linear xs, ys
      n   = xs.size
      xys = xs.zip(ys)
      sx  = sigma xs
      sy  = sigma ys
      sx2 = sigma(xs)  { |x|   x ** 2 }
      sxy = sigma(xys) { |x,y| x * y  }

      c = n * sx2 - sx**2
      a = (sy * sx2 - sx * sxy) / c
      b = ( n * sxy - sx * sy ) / c

      return a, b, fit_error(xys) { |x| a + b * x }
    end


    def fit_power xs, ys
      n       = xs.size
      xys     = xs.zip(ys)
      slnxlny = sigma(xys) { |x, y| Math.log(x) * Math.log(y) }
      slnx    = sigma(xs)  { |x   | Math.log(x)               }
      slny    = sigma(ys)  { |   y| Math.log(y)               }
      slnx2   = sigma(xs)  { |x   | Math.log(x) ** 2          }

      b = (n * slnxlny - slnx * slny) / (n * slnx2 - slnx ** 2);
      a = (slny - b * slnx) / n

      return Math.exp(a), b, fit_error(xys) { |x| (Math.exp(a) * (x ** b)) }
    end


    def sigma enum, &block
      enum = enum.map(&block) if block
      enum.inject { |sum, n| sum + n }
    end


    def validation_for_fit msg, threshold
      proc do |range, times|
        #nodyna <send-1451> <SD MODERATE (change-prone variables)>
        a, b, rr = send "fit_#{msg}", range, times
        assert_operator rr, :>=, threshold
        [a, b, rr]
      end
    end
  end
end

class MiniTest::Spec

  def self.bench name, &block
    #nodyna <define_method-1452> <DM COMPLEX (events)>
    define_method "bench_#{name.gsub(/\W+/, '_')}", &block
  end


  def self.bench_range &block
    return super unless block

    meta = (class << self; self; end)
    #nodyna <send-1453> <SD MODERATE (private methods)>
    #nodyna <define_method-1454> <DM COMPLEX (events)>
    meta.send :define_method, "bench_range", &block
  end


  def self.bench_performance_linear name, threshold = 0.99, &work
    bench name do
      assert_performance_linear threshold, &work
    end
  end


  def self.bench_performance_constant name, threshold = 0.99, &work
    bench name do
      assert_performance_constant threshold, &work
    end
  end


  def self.bench_performance_exponential name, threshold = 0.99, &work
    bench name do
      assert_performance_exponential threshold, &work
    end
  end
end
