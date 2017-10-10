
def sysread(io, size)
  buf = ""
  while size > 0
    tmp = io.sysread(size)
    buf << tmp
    size -= tmp.bytesize
  end
  return buf
end

STDIN.binmode

len = sysread(STDIN, 8).to_i
out = sysread(STDIN, len)
STDOUT.reopen(open(out, "w"))

len = sysread(STDIN, 8).to_i
err = sysread(STDIN, len)
STDERR.reopen(open(err, "w"))

len  = sysread(STDIN, 8).to_i
dump = sysread(STDIN, len)
hash = Marshal.restore(dump)
ENV.keys.each{|name| ENV.delete(name) }
hash.each{|k, v| ENV[k] = v if v }

dir = File::dirname(ENV["SCRIPT_FILENAME"])
Dir::chdir dir

if ARGV[0]
  argv = ARGV.dup
  argv << ENV["SCRIPT_FILENAME"]
  exec(*argv)
end
exec ENV["SCRIPT_FILENAME"]
