$DEBUG_RDOC = nil



module RDoc


  class Error < RuntimeError; end


  VERSION = '4.2.0'


  VISIBILITIES = [:public, :protected, :private]


  DOT_DOC_FILENAME = ".document"


  GENERAL_MODIFIERS = %w[nodoc].freeze


  CLASS_MODIFIERS = GENERAL_MODIFIERS


  ATTR_MODIFIERS = GENERAL_MODIFIERS


  CONSTANT_MODIFIERS = GENERAL_MODIFIERS


  METHOD_MODIFIERS = GENERAL_MODIFIERS +
    %w[arg args yield yields notnew not-new not_new doc]


  def self.load_yaml
    begin
      gem 'psych'
    rescue Gem::LoadError
    end

    begin
      require 'psych'
    rescue ::LoadError
    ensure
      require 'yaml'
    end
  end

  autoload :RDoc,           'rdoc/rdoc'

  autoload :TestCase,       'rdoc/test_case'

  autoload :CrossReference, 'rdoc/cross_reference'
  autoload :ERBIO,          'rdoc/erbio'
  autoload :ERBPartial,     'rdoc/erb_partial'
  autoload :Encoding,       'rdoc/encoding'
  autoload :Generator,      'rdoc/generator'
  autoload :Options,        'rdoc/options'
  autoload :Parser,         'rdoc/parser'
  autoload :Servlet,        'rdoc/servlet'
  autoload :RI,             'rdoc/ri'
  autoload :Stats,          'rdoc/stats'
  autoload :Store,          'rdoc/store'
  autoload :Task,           'rdoc/task'
  autoload :Text,           'rdoc/text'

  autoload :Markdown,       'rdoc/markdown'
  autoload :Markup,         'rdoc/markup'
  autoload :RD,             'rdoc/rd'
  autoload :TomDoc,         'rdoc/tom_doc'

  autoload :KNOWN_CLASSES,  'rdoc/known_classes'

  autoload :RubyLex,        'rdoc/ruby_lex'
  autoload :RubyToken,      'rdoc/ruby_token'
  autoload :TokenStream,    'rdoc/token_stream'

  autoload :Comment,        'rdoc/comment'

  autoload :I18n,           'rdoc/i18n'

  autoload :CodeObject,     'rdoc/code_object'

  autoload :Context,        'rdoc/context'
  autoload :TopLevel,       'rdoc/top_level'

  autoload :AnonClass,      'rdoc/anon_class'
  autoload :ClassModule,    'rdoc/class_module'
  autoload :NormalClass,    'rdoc/normal_class'
  autoload :NormalModule,   'rdoc/normal_module'
  autoload :SingleClass,    'rdoc/single_class'

  autoload :Alias,          'rdoc/alias'
  autoload :AnyMethod,      'rdoc/any_method'
  autoload :MethodAttr,     'rdoc/method_attr'
  autoload :GhostMethod,    'rdoc/ghost_method'
  autoload :MetaMethod,     'rdoc/meta_method'
  autoload :Attr,           'rdoc/attr'

  autoload :Constant,       'rdoc/constant'
  autoload :Mixin,          'rdoc/mixin'
  autoload :Include,        'rdoc/include'
  autoload :Extend,         'rdoc/extend'
  autoload :Require,        'rdoc/require'

end

