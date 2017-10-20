require 'prettyprint'

module Kernel
  def pretty_inspect
    PP.pp(self, '')
  end

  private
  def pp(*objs) # :nodoc:
    objs.each {|obj|
      PP.pp(obj)
    }
    objs.size <= 1 ? objs.first : objs
  end
  module_function :pp # :nodoc:
end


class PP < PrettyPrint
  def PP.pp(obj, out=$>, width=79)
    q = PP.new(out, width)
    q.guard_inspect_key {q.pp obj}
    q.flush
    out << "\n"
  end

  def PP.singleline_pp(obj, out=$>)
    q = SingleLine.new(out)
    q.guard_inspect_key {q.pp obj}
    q.flush
    out
  end

  def PP.mcall(obj, mod, meth, *args, &block)
    mod.instance_method(meth).bind(obj).call(*args, &block)
  end

  @sharing_detection = false
  class << self
    attr_accessor :sharing_detection
  end

  module PPMethods

    def guard_inspect_key
      if Thread.current[:__recursive_key__] == nil
        Thread.current[:__recursive_key__] = {}.taint
      end

      if Thread.current[:__recursive_key__][:inspect] == nil
        Thread.current[:__recursive_key__][:inspect] = {}.taint
      end

      save = Thread.current[:__recursive_key__][:inspect]

      begin
        Thread.current[:__recursive_key__][:inspect] = {}.taint
        yield
      ensure
        Thread.current[:__recursive_key__][:inspect] = save
      end
    end

    def check_inspect_key(id)
      Thread.current[:__recursive_key__] &&
      Thread.current[:__recursive_key__][:inspect] &&
      Thread.current[:__recursive_key__][:inspect].include?(id)
    end

    def push_inspect_key(id)
      Thread.current[:__recursive_key__][:inspect][id] = true
    end

    def pop_inspect_key(id)
      Thread.current[:__recursive_key__][:inspect].delete id
    end

    def pp(obj)
      id = obj.object_id

      if check_inspect_key(id)
        group {obj.pretty_print_cycle self}
        return
      end

      begin
        push_inspect_key(id)
        group {obj.pretty_print self}
      ensure
        pop_inspect_key(id) unless PP.sharing_detection
      end
    end

    def object_group(obj, &block) # :yield:
      group(1, '#<' + obj.class.name, '>', &block)
    end

    def object_address_group(obj, &block)
      str = Kernel.instance_method(:to_s).bind(obj).call
      str.chomp!('>')
      group(1, str, '>', &block)
    end

    def comma_breakable
      text ','
      breakable
    end

    def seplist(list, sep=nil, iter_method=:each) # :yield: element
      sep ||= lambda { comma_breakable }
      first = true
      list.__send__(iter_method) {|*v|
        if first
          first = false
        else
          sep.call
        end
        yield(*v)
      }
    end

    def pp_object(obj)
      object_address_group(obj) {
        seplist(obj.pretty_print_instance_variables, lambda { text ',' }) {|v|
          breakable
          v = v.to_s if Symbol === v
          text v
          text '='
          group(1) {
            breakable ''
            #nodyna <instance_eval-1996> <IEV COMPLEX (block execution)>
            pp(obj.instance_eval(v))
          }
        }
      }
    end

    def pp_hash(obj)
      group(1, '{', '}') {
        seplist(obj, nil, :each_pair) {|k, v|
          group {
            pp k
            text '=>'
            group(1) {
              breakable ''
              pp v
            }
          }
        }
      }
    end
  end

  include PPMethods

  class SingleLine < PrettyPrint::SingleLine # :nodoc:
    include PPMethods
  end

  module ObjectMixin # :nodoc:

    def pretty_print(q)
      method_method = Object.instance_method(:method).bind(self)
      begin
        inspect_method = method_method.call(:inspect)
      rescue NameError
      end
      if inspect_method && /\(Kernel\)#/ !~ inspect_method.inspect
        q.text self.inspect
      elsif !inspect_method && self.respond_to?(:inspect)
        q.text self.inspect
      else
        q.pp_object(self)
      end
    end

    def pretty_print_cycle(q)
      q.object_address_group(self) {
        q.breakable
        q.text '...'
      }
    end

    def pretty_print_instance_variables
      instance_variables.sort
    end

    def pretty_print_inspect
      if /\(PP::ObjectMixin\)#/ =~ Object.instance_method(:method).bind(self).call(:pretty_print).inspect
        raise "pretty_print is not overridden for #{self.class}"
      end
      PP.singleline_pp(self, '')
    end
  end
end

class Array # :nodoc:
  def pretty_print(q) # :nodoc:
    q.group(1, '[', ']') {
      q.seplist(self) {|v|
        q.pp v
      }
    }
  end

  def pretty_print_cycle(q) # :nodoc:
    q.text(empty? ? '[]' : '[...]')
  end
end

class Hash # :nodoc:
  def pretty_print(q) # :nodoc:
    q.pp_hash self
  end

  def pretty_print_cycle(q) # :nodoc:
    q.text(empty? ? '{}' : '{...}')
  end
end

class << ENV # :nodoc:
  def pretty_print(q) # :nodoc:
    h = {}
    ENV.keys.sort.each {|k|
      h[k] = ENV[k]
    }
    q.pp_hash h
  end
end

class Struct # :nodoc:
  def pretty_print(q) # :nodoc:
    q.group(1, sprintf("#<struct %s", PP.mcall(self, Kernel, :class).name), '>') {
      q.seplist(PP.mcall(self, Struct, :members), lambda { q.text "," }) {|member|
        q.breakable
        q.text member.to_s
        q.text '='
        q.group(1) {
          q.breakable ''
          q.pp self[member]
        }
      }
    }
  end

  def pretty_print_cycle(q) # :nodoc:
    q.text sprintf("#<struct %s:...>", PP.mcall(self, Kernel, :class).name)
  end
end

class Range # :nodoc:
  def pretty_print(q) # :nodoc:
    q.pp self.begin
    q.breakable ''
    q.text(self.exclude_end? ? '...' : '..')
    q.breakable ''
    q.pp self.end
  end
end

class File < IO # :nodoc:
  class Stat # :nodoc:
    def pretty_print(q) # :nodoc:
      require 'etc.so'
      q.object_group(self) {
        q.breakable
        q.text sprintf("dev=0x%x", self.dev); q.comma_breakable
        q.text "ino="; q.pp self.ino; q.comma_breakable
        q.group {
          m = self.mode
          q.text sprintf("mode=0%o", m)
          q.breakable
          q.text sprintf("(%s %c%c%c%c%c%c%c%c%c)",
            self.ftype,
            (m & 0400 == 0 ? ?- : ?r),
            (m & 0200 == 0 ? ?- : ?w),
            (m & 0100 == 0 ? (m & 04000 == 0 ? ?- : ?S) :
                             (m & 04000 == 0 ? ?x : ?s)),
            (m & 0040 == 0 ? ?- : ?r),
            (m & 0020 == 0 ? ?- : ?w),
            (m & 0010 == 0 ? (m & 02000 == 0 ? ?- : ?S) :
                             (m & 02000 == 0 ? ?x : ?s)),
            (m & 0004 == 0 ? ?- : ?r),
            (m & 0002 == 0 ? ?- : ?w),
            (m & 0001 == 0 ? (m & 01000 == 0 ? ?- : ?T) :
                             (m & 01000 == 0 ? ?x : ?t)))
        }
        q.comma_breakable
        q.text "nlink="; q.pp self.nlink; q.comma_breakable
        q.group {
          q.text "uid="; q.pp self.uid
          begin
            pw = Etc.getpwuid(self.uid)
          rescue ArgumentError
          end
          if pw
            q.breakable; q.text "(#{pw.name})"
          end
        }
        q.comma_breakable
        q.group {
          q.text "gid="; q.pp self.gid
          begin
            gr = Etc.getgrgid(self.gid)
          rescue ArgumentError
          end
          if gr
            q.breakable; q.text "(#{gr.name})"
          end
        }
        q.comma_breakable
        q.group {
          q.text sprintf("rdev=0x%x", self.rdev)
          if self.rdev_major && self.rdev_minor
            q.breakable
            q.text sprintf('(%d, %d)', self.rdev_major, self.rdev_minor)
          end
        }
        q.comma_breakable
        q.text "size="; q.pp self.size; q.comma_breakable
        q.text "blksize="; q.pp self.blksize; q.comma_breakable
        q.text "blocks="; q.pp self.blocks; q.comma_breakable
        q.group {
          t = self.atime
          q.text "atime="; q.pp t
          q.breakable; q.text "(#{t.tv_sec})"
        }
        q.comma_breakable
        q.group {
          t = self.mtime
          q.text "mtime="; q.pp t
          q.breakable; q.text "(#{t.tv_sec})"
        }
        q.comma_breakable
        q.group {
          t = self.ctime
          q.text "ctime="; q.pp t
          q.breakable; q.text "(#{t.tv_sec})"
        }
      }
    end
  end
end

class MatchData # :nodoc:
  def pretty_print(q) # :nodoc:
    nc = []
    self.regexp.named_captures.each {|name, indexes|
      indexes.each {|i| nc[i] = name }
    }
    q.object_group(self) {
      q.breakable
      q.seplist(0...self.size, lambda { q.breakable }) {|i|
        if i == 0
          q.pp self[i]
        else
          if nc[i]
            q.text nc[i]
          else
            q.pp i
          end
          q.text ':'
          q.pp self[i]
        end
      }
    }
  end
end

class Object < BasicObject # :nodoc:
  include PP::ObjectMixin
end

[Numeric, Symbol, FalseClass, TrueClass, NilClass, Module].each {|c|
  #nodyna <class_eval-1997> <CE MODERATE (define methods)>
  c.class_eval {
    def pretty_print_cycle(q)
      q.text inspect
    end
  }
}

[Numeric, FalseClass, TrueClass, Module].each {|c|
  #nodyna <class_eval-1998> <CE MODERATE (define methods)>
  c.class_eval {
    def pretty_print(q)
      q.text inspect
    end
  }
}
