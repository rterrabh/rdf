class PrettyPrint

  def PrettyPrint.format(output='', maxwidth=79, newline="\n", genspace=lambda {|n| ' ' * n})
    q = PrettyPrint.new(output, maxwidth, newline, &genspace)
    yield q
    q.flush
    output
  end

  def PrettyPrint.singleline_format(output='', maxwidth=nil, newline=nil, genspace=nil)
    q = SingleLine.new(output)
    yield q
    output
  end

  def initialize(output='', maxwidth=79, newline="\n", &genspace)
    @output = output
    @maxwidth = maxwidth
    @newline = newline
    @genspace = genspace || lambda {|n| ' ' * n}

    @output_width = 0
    @buffer_width = 0
    @buffer = []

    root_group = Group.new(0)
    @group_stack = [root_group]
    @group_queue = GroupQueue.new(root_group)
    @indent = 0
  end

  attr_reader :output

  attr_reader :maxwidth

  attr_reader :newline

  attr_reader :genspace

  attr_reader :indent

  attr_reader :group_queue

  def current_group
    @group_stack.last
  end

  def break_outmost_groups
    while @maxwidth < @output_width + @buffer_width
      return unless group = @group_queue.deq
      until group.breakables.empty?
        data = @buffer.shift
        @output_width = data.output(@output, @output_width)
        @buffer_width -= data.width
      end
      while !@buffer.empty? && Text === @buffer.first
        text = @buffer.shift
        @output_width = text.output(@output, @output_width)
        @buffer_width -= text.width
      end
    end
  end

  def text(obj, width=obj.length)
    if @buffer.empty?
      @output << obj
      @output_width += width
    else
      text = @buffer.last
      unless Text === text
        text = Text.new
        @buffer << text
      end
      text.add(obj, width)
      @buffer_width += width
      break_outmost_groups
    end
  end

  def fill_breakable(sep=' ', width=sep.length)
    group { breakable sep, width }
  end

  def breakable(sep=' ', width=sep.length)
    group = @group_stack.last
    if group.break?
      flush
      @output << @newline
      @output << @genspace.call(@indent)
      @output_width = @indent
      @buffer_width = 0
    else
      @buffer << Breakable.new(sep, width, self)
      @buffer_width += width
      break_outmost_groups
    end
  end

  def group(indent=0, open_obj='', close_obj='', open_width=open_obj.length, close_width=close_obj.length)
    text open_obj, open_width
    group_sub {
      nest(indent) {
        yield
      }
    }
    text close_obj, close_width
  end

  def group_sub
    group = Group.new(@group_stack.last.depth + 1)
    @group_stack.push group
    @group_queue.enq group
    begin
      yield
    ensure
      @group_stack.pop
      if group.breakables.empty?
        @group_queue.delete group
      end
    end
  end

  def nest(indent)
    @indent += indent
    begin
      yield
    ensure
      @indent -= indent
    end
  end

  def flush
    @buffer.each {|data|
      @output_width = data.output(@output, @output_width)
    }
    @buffer.clear
    @buffer_width = 0
  end

  class Text # :nodoc:

    def initialize
      @objs = []
      @width = 0
    end

    attr_reader :width

    def output(out, output_width)
      @objs.each {|obj| out << obj}
      output_width + @width
    end

    def add(obj, width)
      @objs << obj
      @width += width
    end
  end

  class Breakable # :nodoc:

    def initialize(sep, width, q)
      @obj = sep
      @width = width
      @pp = q
      @indent = q.indent
      @group = q.current_group
      @group.breakables.push self
    end

    attr_reader :obj

    attr_reader :width

    attr_reader :indent

    def output(out, output_width)
      @group.breakables.shift
      if @group.break?
        out << @pp.newline
        out << @pp.genspace.call(@indent)
        @indent
      else
        @pp.group_queue.delete @group if @group.breakables.empty?
        out << @obj
        output_width + @width
      end
    end
  end

  class Group # :nodoc:
    def initialize(depth)
      @depth = depth
      @breakables = []
      @break = false
    end

    attr_reader :depth

    attr_reader :breakables

    def break
      @break = true
    end

    def break?
      @break
    end

    def first?
      if defined? @first
        false
      else
        @first = false
        true
      end
    end
  end

  class GroupQueue # :nodoc:
    def initialize(*groups)
      @queue = []
      groups.each {|g| enq g}
    end

    def enq(group)
      depth = group.depth
      @queue << [] until depth < @queue.length
      @queue[depth] << group
    end

    def deq
      @queue.each {|gs|
        (gs.length-1).downto(0) {|i|
          unless gs[i].breakables.empty?
            group = gs.slice!(i, 1).first
            group.break
            return group
          end
        }
        gs.each {|group| group.break}
        gs.clear
      }
      return nil
    end

    def delete(group)
      @queue[group.depth].delete(group)
    end
  end

  class SingleLine
    def initialize(output, maxwidth=nil, newline=nil)
      @output = output
      @first = [true]
    end

    def text(obj, width=nil)
      @output << obj
    end

    def breakable(sep=' ', width=nil)
      @output << sep
    end

    def nest(indent) # :nodoc:
      yield
    end

    def group(indent=nil, open_obj='', close_obj='', open_width=nil, close_width=nil)
      @first.push true
      @output << open_obj
      yield
      @output << close_obj
      @first.pop
    end

    def flush # :nodoc:
    end

    def first?
      result = @first[-1]
      @first[-1] = false
      result
    end
  end
end
