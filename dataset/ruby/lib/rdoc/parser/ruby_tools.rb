
module RDoc::Parser::RubyTools

  include RDoc::RubyToken


  def add_token_listener(obj)
    @token_listeners ||= []
    @token_listeners << obj
  end


  def get_tk
    tk = nil

    if @tokens.empty? then
      tk = @scanner.token
      @read.push @scanner.get_readed
      puts "get_tk1 => #{tk.inspect}" if $TOKEN_DEBUG
    else
      @read.push @unget_read.shift
      tk = @tokens.shift
      puts "get_tk2 => #{tk.inspect}" if $TOKEN_DEBUG
    end

    tk = nil if TkEND_OF_SCRIPT === tk

    if TkSYMBEG === tk then
      set_token_position tk.line_no, tk.char_no

      case tk1 = get_tk
      when TkId, TkOp, TkSTRING, TkDSTRING, TkSTAR, TkAMPER then
        if tk1.respond_to?(:name) then
          tk = Token(TkSYMBOL).set_text(":" + tk1.name)
        else
          tk = Token(TkSYMBOL).set_text(":" + tk1.text)
        end

        @token_listeners.each do |obj|
          obj.pop_token
        end if @token_listeners
      else
        tk = tk1
      end
    end

    @token_listeners.each do |obj|
      obj.add_token(tk)
    end if @token_listeners

    tk
  end


  def get_tk_until(*tokens)
    read = []

    loop do
      tk = get_tk

      case tk
      when *tokens then
        unget_tk tk
        break
      end

      read << tk
    end

    read
  end


  def get_tkread
    read = @read.join("")
    @read = []
    read
  end


  def peek_read
    @read.join('')
  end


  def peek_tk
    unget_tk(tk = get_tk)
    tk
  end


  def remove_token_listener(obj)
    @token_listeners.delete(obj)
  end


  def reset
    @read       = []
    @tokens     = []
    @unget_read = []
    @nest = 0
  end


  def skip_tkspace(skip_nl = true) # HACK dup
    tokens = []

    while TkSPACE === (tk = get_tk) or (skip_nl and TkNL === tk) do
      tokens.push tk
    end

    unget_tk tk
    tokens
  end


  def token_listener(obj)
    add_token_listener obj
    yield
  ensure
    remove_token_listener obj
  end


  def unget_tk(tk)
    @tokens.unshift tk
    @unget_read.unshift @read.pop

    @token_listeners.each do |obj|
      obj.pop_token
    end if @token_listeners

    nil
  end

end


