require 'yaml'
require 'pstore'


class YAML::Store < PStore

  def initialize file_name, yaml_opts = {}
    @opt = yaml_opts
    super
  end


  def dump(table)
    YAML.dump @table
  end

  def load(content)
    table = YAML.load(content)
    if table == false
      {}
    else
      table
    end
  end

  def marshal_dump_supports_canonical_option?
    false
  end

  EMPTY_MARSHAL_DATA = YAML.dump({})
  EMPTY_MARSHAL_CHECKSUM = Digest::MD5.digest(EMPTY_MARSHAL_DATA)
  def empty_marshal_data
    EMPTY_MARSHAL_DATA
  end
  def empty_marshal_checksum
    EMPTY_MARSHAL_CHECKSUM
  end
end
