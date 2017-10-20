require 'active_support/core_ext/array/extract_options'

class Module
  def mattr_reader(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless sym =~ /^[_A-Za-z]\w*$/
      #nodyna <class_eval-1036> <CE COMPLEX (define methods)>
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        @@#{sym} = nil unless defined? @@#{sym}

        def self.#{sym}
          @@#{sym}
        end
      EOS

      unless options[:instance_reader] == false || options[:instance_accessor] == false
        #nodyna <class_eval-1037> <CE COMPLEX (define methods)>
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}
            @@#{sym}
          end
        EOS
      end
      #nodyna <class_variable_set-1038> <CVS COMPLEX (change-prone variable)>
      class_variable_set("@@#{sym}", yield) if block_given?
    end
  end
  alias :cattr_reader :mattr_reader

  def mattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new("invalid attribute name: #{sym}") unless sym =~ /^[_A-Za-z]\w*$/
      #nodyna <class_eval-1039> <CE COMPLEX (define methods)>
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        @@#{sym} = nil unless defined? @@#{sym}

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      EOS

      unless options[:instance_writer] == false || options[:instance_accessor] == false
        #nodyna <class_eval-1040> <CE COMPLEX (define methods)>
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        EOS
      end
      #nodyna <send-1041> <SD COMPLEX (array)>
      send("#{sym}=", yield) if block_given?
    end
  end
  alias :cattr_writer :mattr_writer

  def mattr_accessor(*syms, &blk)
    mattr_reader(*syms, &blk)
    mattr_writer(*syms, &blk)
  end
  alias :cattr_accessor :mattr_accessor
end
