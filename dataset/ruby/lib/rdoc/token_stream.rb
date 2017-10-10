
module RDoc::TokenStream


  def self.to_html token_stream
    token_stream.map do |t|
      next unless t

      style = case t
              when RDoc::RubyToken::TkCONSTANT then 'ruby-constant'
              when RDoc::RubyToken::TkKW       then 'ruby-keyword'
              when RDoc::RubyToken::TkIVAR     then 'ruby-ivar'
              when RDoc::RubyToken::TkOp       then 'ruby-operator'
              when RDoc::RubyToken::TkId       then 'ruby-identifier'
              when RDoc::RubyToken::TkNode     then 'ruby-node'
              when RDoc::RubyToken::TkCOMMENT  then 'ruby-comment'
              when RDoc::RubyToken::TkREGEXP   then 'ruby-regexp'
              when RDoc::RubyToken::TkSTRING   then 'ruby-string'
              when RDoc::RubyToken::TkVal      then 'ruby-value'
              end

      text = CGI.escapeHTML t.text

      if style then
        "<span class=\"#{style}\">#{text}</span>"
      else
        text
      end
    end.join
  end


  def add_tokens(*tokens)
    tokens.flatten.each { |token| @token_stream << token }
  end

  alias add_token add_tokens


  def collect_tokens
    @token_stream = []
  end

  alias start_collecting_tokens collect_tokens


  def pop_token
    @token_stream.pop
  end


  def token_stream
    @token_stream
  end


  def tokens_to_s
    token_stream.compact.map { |token| token.text }.join ''
  end

end

