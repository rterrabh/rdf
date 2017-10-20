module Exception2MessageMapper

  E2MM = Exception2MessageMapper # :nodoc:

  def E2MM.extend_object(cl)
    super
    cl.bind(self) unless cl < E2MM
  end

  def bind(cl)
    #nodyna <module_eval-1999> <ME COMPLEX (define methods)>
    self.module_eval %[
      def Raise(err = nil, *rest)
        Exception2MessageMapper.Raise(self.class, err, *rest)
      end
      alias Fail Raise

      def self.included(mod)
        mod.extend Exception2MessageMapper
      end
    ]
  end

  def Raise(err = nil, *rest)
    E2MM.Raise(self, err, *rest)
  end
  alias Fail Raise
  alias fail Raise

  def def_e2message(c, m)
    E2MM.def_e2message(self, c, m)
  end

  def def_exception(n, m, s = StandardError)
    E2MM.def_exception(self, n, m, s)
  end

  @MessageMap = {}

  def E2MM.def_e2message(k, c, m)
    #nodyna <instance_eval-2000> <IEV EASY (private access)>
    E2MM.instance_eval{@MessageMap[[k, c]] = m}
    c
  end

  def E2MM.def_exception(k, n, m, s = StandardError)
    n = n.id2name if n.kind_of?(Fixnum)
    e = Class.new(s)
    #nodyna <instance_eval-2001> <IEV EASY (private access)>
    E2MM.instance_eval{@MessageMap[[k, e]] = m}
    #nodyna <const_set-2002> <CS MODERATE (change-prone variable)>
    k.const_set(n, e)
  end

  def E2MM.Raise(klass = E2MM, err = nil, *rest)
    if form = e2mm_message(klass, err)
      b = $@.nil? ? caller(1) : $@
      b.shift if b[0] =~ /^#{Regexp.quote(__FILE__)}:/
      raise err, sprintf(form, *rest), b
    else
      E2MM.Fail E2MM, ErrNotRegisteredException, err.inspect
    end
  end
  class << E2MM
    alias Fail Raise
  end

  def E2MM.e2mm_message(klass, exp)
    for c in klass.ancestors
      if mes = @MessageMap[[c,exp]]
        #nodyna <instance_eval-2003> <IEV COMPLEX (private access)>
        m = klass.instance_eval('"' + mes + '"')
        return m
      end
    end
    nil
  end
  class << self
    alias message e2mm_message
  end

  E2MM.def_exception(E2MM,
                     :ErrNotRegisteredException,
                     "not registered exception(%s)")
end


