

module Open3

  def popen3(*cmd, **opts, &block)
    in_r, in_w = IO.pipe
    opts[:in] = in_r
    in_w.sync = true

    out_r, out_w = IO.pipe
    opts[:out] = out_w

    err_r, err_w = IO.pipe
    opts[:err] = err_w

    popen_run(cmd, opts, [in_r, out_w, err_w], [in_w, out_r, err_r], &block)
  end
  module_function :popen3

  def popen2(*cmd, **opts, &block)
    in_r, in_w = IO.pipe
    opts[:in] = in_r
    in_w.sync = true

    out_r, out_w = IO.pipe
    opts[:out] = out_w

    popen_run(cmd, opts, [in_r, out_w], [in_w, out_r], &block)
  end
  module_function :popen2

  def popen2e(*cmd, **opts, &block)
    in_r, in_w = IO.pipe
    opts[:in] = in_r
    in_w.sync = true

    out_r, out_w = IO.pipe
    opts[[:out, :err]] = out_w

    popen_run(cmd, opts, [in_r, out_w], [in_w, out_r], &block)
  end
  module_function :popen2e

  def popen_run(cmd, opts, child_io, parent_io) # :nodoc:
    pid = spawn(*cmd, opts)
    wait_thr = Process.detach(pid)
    child_io.each {|io| io.close }
    result = [*parent_io, wait_thr]
    if defined? yield
      begin
        return yield(*result)
      ensure
        parent_io.each{|io| io.close unless io.closed?}
        wait_thr.join
      end
    end
    result
  end
  module_function :popen_run
  class << self
    private :popen_run
  end

  def capture3(*cmd, stdin_data: '', binmode: false, **opts)
    popen3(*cmd, opts) {|i, o, e, t|
      if binmode
        i.binmode
        o.binmode
        e.binmode
      end
      out_reader = Thread.new { o.read }
      err_reader = Thread.new { e.read }
      begin
        i.write stdin_data
      rescue Errno::EPIPE
      end
      i.close
      [out_reader.value, err_reader.value, t.value]
    }
  end
  module_function :capture3

  def capture2(*cmd, stdin_data: nil, binmode: false, **opts)
    popen2(*cmd, opts) {|i, o, t|
      if binmode
        i.binmode
        o.binmode
      end
      out_reader = Thread.new { o.read }
      if stdin_data
        begin
          i.write stdin_data
        rescue Errno::EPIPE
        end
      end
      i.close
      [out_reader.value, t.value]
    }
  end
  module_function :capture2

  def capture2e(*cmd, stdin_data: nil, binmode: false, **opts)
    popen2e(*cmd, opts) {|i, oe, t|
      if binmode
        i.binmode
        oe.binmode
      end
      outerr_reader = Thread.new { oe.read }
      if stdin_data
        begin
          i.write stdin_data
        rescue Errno::EPIPE
        end
      end
      i.close
      [outerr_reader.value, t.value]
    }
  end
  module_function :capture2e

  def pipeline_rw(*cmds, **opts, &block)
    in_r, in_w = IO.pipe
    opts[:in] = in_r
    in_w.sync = true

    out_r, out_w = IO.pipe
    opts[:out] = out_w

    pipeline_run(cmds, opts, [in_r, out_w], [in_w, out_r], &block)
  end
  module_function :pipeline_rw

  def pipeline_r(*cmds, **opts, &block)
    out_r, out_w = IO.pipe
    opts[:out] = out_w

    pipeline_run(cmds, opts, [out_w], [out_r], &block)
  end
  module_function :pipeline_r

  def pipeline_w(*cmds, **opts, &block)
    in_r, in_w = IO.pipe
    opts[:in] = in_r
    in_w.sync = true

    pipeline_run(cmds, opts, [in_r], [in_w], &block)
  end
  module_function :pipeline_w

  def pipeline_start(*cmds, **opts, &block)
    if block
      pipeline_run(cmds, opts, [], [], &block)
    else
      ts, = pipeline_run(cmds, opts, [], [])
      ts
    end
  end
  module_function :pipeline_start

  def pipeline(*cmds, **opts)
    pipeline_run(cmds, opts, [], []) {|ts|
      ts.map {|t| t.value }
    }
  end
  module_function :pipeline

  def pipeline_run(cmds, pipeline_opts, child_io, parent_io) # :nodoc:
    if cmds.empty?
      raise ArgumentError, "no commands"
    end

    opts_base = pipeline_opts.dup
    opts_base.delete :in
    opts_base.delete :out

    wait_thrs = []
    r = nil
    cmds.each_with_index {|cmd, i|
      cmd_opts = opts_base.dup
      if String === cmd
        cmd = [cmd]
      else
        cmd_opts.update cmd.pop if Hash === cmd.last
      end
      if i == 0
        if !cmd_opts.include?(:in)
          if pipeline_opts.include?(:in)
            cmd_opts[:in] = pipeline_opts[:in]
          end
        end
      else
        cmd_opts[:in] = r
      end
      if i != cmds.length - 1
        r2, w2 = IO.pipe
        cmd_opts[:out] = w2
      else
        if !cmd_opts.include?(:out)
          if pipeline_opts.include?(:out)
            cmd_opts[:out] = pipeline_opts[:out]
          end
        end
      end
      pid = spawn(*cmd, cmd_opts)
      wait_thrs << Process.detach(pid)
      r.close if r
      w2.close if w2
      r = r2
    }
    result = parent_io + [wait_thrs]
    child_io.each {|io| io.close }
    if defined? yield
      begin
        return yield(*result)
      ensure
        parent_io.each{|io| io.close unless io.closed?}
        wait_thrs.each {|t| t.join }
      end
    end
    result
  end
  module_function :pipeline_run
  class << self
    private :pipeline_run
  end

end
