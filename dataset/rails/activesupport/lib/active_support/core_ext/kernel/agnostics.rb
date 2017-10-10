class Object
  def `(command) #:nodoc:
    super
  rescue Errno::ENOENT => e
    STDERR.puts "#$0: #{e}"
  end
end
