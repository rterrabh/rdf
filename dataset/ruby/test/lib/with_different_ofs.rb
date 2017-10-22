module DifferentOFS
  module WithDifferentOFS
    def setup
      super
      @ofs, $, = $,, "-"
    end
    def teardown
      $, = @ofs
      super
    end
  end

  def self.extended(klass)
    super(klass)
    #nodyna <const_set-1455> <CS COMPLEX (static values)>
    #nodyna <class_eval-1456> <CE TRIVIAL (block execution)>
    klass.const_set(:DifferentOFS, Class.new(klass).class_eval {include WithDifferentOFS}).name
  end
end
