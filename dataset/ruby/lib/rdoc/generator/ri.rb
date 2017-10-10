
class RDoc::Generator::RI

  RDoc::RDoc.add_generator self


  DESCRIPTION = 'creates ri data files'


  def initialize store, options #:not-new:
    @options    = options
    @store      = store
    @store.path = '.'
  end


  def generate
    @store.save
  end

end

