class Fftw < Formula
  desc "C routines to compute the Discrete Fourier Transform"
  homepage "http://www.fftw.org"
  url "http://www.fftw.org/fftw-3.3.4.tar.gz"
  sha256 "8f0cde90929bc05587c3368d2f15cd0530a60b8a9912a8e2979a72dbe5af0982"
  revision 1

  bottle do
    cellar :any
    sha1 "b5c2d04489567aff02e2e002d906ce7349057f6e" => :yosemite
    sha1 "af376c8efd9de7501d56f763a1ead65a5d32e533" => :mavericks
    sha1 "1585929f22c6851d87cf9d451cd26ff403991a8c" => :mountain_lion
  end

  option "with-fortran", "Enable Fortran bindings"
  option :universal
  option "with-mpi", "Enable MPI parallel transforms"
  option "with-openmp", "Enable OpenMP parallel transforms"

  depends_on :fortran => :optional
  depends_on :mpi => [:cc, :optional]
  needs :openmp if build.with? "openmp"

  def install
    args = ["--enable-shared",
            "--disable-debug",
            "--prefix=#{prefix}",
            "--enable-threads",
            "--disable-dependency-tracking"]
    simd_args = ["--enable-sse2"]
    simd_args << "--enable-avx" if ENV.compiler == :clang && Hardware::CPU.avx? && !build.bottle?

    args << "--disable-fortran" if build.without? "fortran"
    args << "--enable-mpi" if build.with? "mpi"
    args << "--enable-openmp" if build.with? "openmp"

    ENV.universal_binary if build.universal?

    system "./configure", "--enable-single", *(args + simd_args)
    system "make", "install"

    system "make", "clean"

    system "./configure", *(args + simd_args)
    system "make", "install"

    system "make", "clean"

    system "./configure", "--enable-long-double", *args
    system "make", "install"
  end

  test do
    (testpath/"fftw.c").write <<-TEST_SCRIPT.undent
      int main(int argc, char* *argv)
      {
          fftw_complex *in, *out;
          fftw_plan p;
          long N = 1;
          in = (fftw_complex*) fftw_malloc(sizeof(fftw_complex) * N);
          out = (fftw_complex*) fftw_malloc(sizeof(fftw_complex) * N);
          p = fftw_plan_dft_1d(N, in, out, FFTW_FORWARD, FFTW_ESTIMATE);
          fftw_execute(p); /* repeat as needed */
          fftw_destroy_plan(p);
          fftw_free(in); fftw_free(out);
          return 0;
      }
    TEST_SCRIPT

    system ENV.cc, "-o", "fftw", "fftw.c", "-lfftw3", *ENV.cflags.to_s.split
    system "./fftw"
  end
end
