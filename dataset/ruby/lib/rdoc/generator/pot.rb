
class RDoc::Generator::POT

  RDoc::RDoc.add_generator self


  DESCRIPTION = 'creates .pot file'


  def initialize store, options #:not-new:
    @options    = options
    @store      = store
  end


  def generate
    po = extract_messages
    pot_path = 'rdoc.pot'
    File.open(pot_path, "w") do |pot|
      pot.print(po.to_s)
    end
  end

  def class_dir
    nil
  end

  private
  def extract_messages
    extractor = MessageExtractor.new(@store)
    extractor.extract
  end

  autoload :MessageExtractor, 'rdoc/generator/pot/message_extractor'
  autoload :PO,               'rdoc/generator/pot/po'
  autoload :POEntry,          'rdoc/generator/pot/po_entry'

end
