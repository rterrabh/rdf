require 'tk'

module Tk
  class OptionObj < Hash
    include TkUtil

    def initialize(hash = nil)
      super()
      @observ = []
      update_without_notify(_symbolkey2str(hash)) if hash
    end

    def observ_info
      @observ.dup
    end

    def observs
      @observ.collect{|win|
        if win.kind_of?(Array)
          win[0]
        else
          win
        end
      }
    end

    def _remove_win(win)
      if win.kind_of?(Array)
        widget, method = win
        @observ.delete_if{|x|
          if x.kind_of?(Array)
            x[0] == widget
          else
            x == widget
          end
        }
      else
        @observ.delete_if{|x|
          if x.kind_of?(Array)
            x[0] == win
          else
            x == win
          end
        }
      end
    end
    private :_remove_win

    def assign(*wins)
      wins.each{|win|
        _remove_win(win)
        @observ << win
        notify(win)
      }
      self
    end

    def unassign(*wins)
      wins.each{|win|
        _remove_win(win)
      }
      self
    end

    def notify(target = nil)
      if target
        targets = [target]
      elsif @observ.empty?
        return self
      else
        targets = @observ.dup
      end

      return self if empty?

      org_hash = _symbolkey2str(self)

      targets.each{|win|
        widget = receiver = win
        hash = org_hash
        begin
          if win.kind_of?(Array)
            widget, method, conv_tbl = win
            receiver = widget

            if conv_tbl
              hash = {}
              org_hash.each{|key, val|
                key = conv_tbl[key] if conv_tbl.key?(key)
                next unless key
                if key.kind_of?(Array)
                  key.each{|k| hash[k] = val}
                else
                  hash[key] = val
                end
              }
            end

            if method.kind_of?(Array)
              receiver, method, *args = method
              receiver.__send__(method, *(args << hash))
            elsif method
              widget.__send__(method, hash)
            else
              widget.configure(hash)
            end

          else
            widget.configure(self)
          end
        rescue => e
          if ( ( widget.kind_of?(TkObject) \
                && widget.respond_to?('exist?') \
                && ! receiver.exist? ) \
            || ( receiver.kind_of?(TkObject) \
                && receiver.respond_to?('exist?') \
                && ! receiver.exist? ) )
            @observ.delete(win)
          else
            fail e
          end
        end
      }

      self
    end
    alias apply notify

    def +(hash)
      unless hash.kind_of?(Hash)
        fail ArgumentError, "expect a Hash"
      end
      new_obj = self.dup
      new_obj.update_without_notify(_symbolkey2str(hash))
      new_obj
    end

    alias update_without_notify update

    def update(hash)
      update_without_notify(_symbolkey2str(hash))
      notify
    end

    def configure(key, value=nil)
      if key.kind_of?(Hash)
        update(key)
      else
        store(key,value)
      end
    end

    def [](key)
      super(key.to_s)
    end
    alias cget []

    def store(key, val)
      key = key.to_s
      super(key, val)
      notify
    end
    def []=(key, val)
      store(key,val)
    end

    def replace(hash)
      super(_symbolkey2str(hash))
      notify
    end

    def default(opt)
      fail RuntimeError, "unknown option `#{opt}'"
    end
    private :default

    undef :default=
  end
end
