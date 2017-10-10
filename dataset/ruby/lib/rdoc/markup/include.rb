
class RDoc::Markup::Include


  attr_reader :file


  attr_reader :include_path


  def initialize file, include_path
    @file = file
    @include_path = include_path
  end

  def == other # :nodoc:
    self.class === other and
      @file == other.file and @include_path == other.include_path
  end

  def pretty_print q # :nodoc:
    q.group 2, '[incl ', ']' do
      q.text file
      q.breakable
      q.text 'from '
      q.pp include_path
    end
  end

end

