class Hbc::CLI::InternalStanza < Hbc::CLI::InternalUseBase


  ARTIFACTS = Set.new([
                       :app,
                       :suite,
                       :artifact,
                       :prefpane,
                       :qlplugin,
                       :font,
                       :service,
                       :colorpicker,
                       :binary,
                       :input_method,
                       :internet_plugin,
                       :screen_saver,
                       :pkg,
                       :installer,
                       :stage_only,
                       :nested_container,
                       :uninstall,
                       :postflight,
                       :uninstall_postflight,
                       :preflight,
                       :uninstall_postflight,
                       ])

  def self.run(*arguments)

    table = arguments.include? '--table'
    quiet = arguments.include? '--quiet'
    format = :to_yaml if arguments.include? '--yaml'
    format = :inspect if arguments.include? '--inspect'
    cask_tokens = arguments.reject { |arg| arg.chars.first == '-' }
    stanza = cask_tokens.shift.to_sym
    cask_tokens = Hbc.all_tokens if cask_tokens.empty?

    retval = print_stanzas(stanza, format, table, quiet, *cask_tokens)

    if retval.nil?
      exit 1 if quiet
      raise Hbc::CaskError.new("nothing to print")
    elsif ! retval
      exit 1 if quiet
      raise Hbc::CaskError.new("print incomplete")
    end
  end

  def self.print_stanzas(stanza, format=nil, table=nil, quiet=nil, *cask_tokens)
    count = 0
    stanza = :full_name if stanza == :name
    if ARTIFACTS.include?(stanza)
      artifact_name = stanza
      stanza = :artifacts
    end

    cask_tokens.each do |cask_token|

      print "#{cask_token}\t" if table

      begin
        cask = Hbc.load(cask_token)
      rescue StandardError
        opoo "Cask '#{cask_token}' was not found" unless quiet
        puts ''
        next
      end

      unless cask.respond_to?(stanza)
        opoo "no such stanza '#{stanza}' on Cask '#{cask_token}'" unless quiet
        puts ''
        next
      end

      begin
        #nodyna <send-2867> <not yet classified>
        value = cask.send(stanza)
      rescue StandardError
        opoo "failure calling '#{stanza}' on Cask '#{cask_token}'" unless quiet
        puts ''
        next
      end

      if artifact_name and not value.key?(artifact_name)
        opoo "no such stanza '#{artifact_name}' on Cask '#{cask_token}'" unless quiet
        puts ''
        next
      end

      if artifact_name
        value = value.fetch(artifact_name).to_a.flatten
      end

      if format
        #nodyna <send-2868> <not yet classified>
        puts value.send(format)
      else
        if artifact_name or value.is_a?(Symbol)
          puts value.inspect
        else
          puts value.to_s
        end
      end

      count += 1

    end
    count == 0 ? nil : count == cask_tokens.length
  end

  def self.help
    "Extract and render a specific stanza for the given Casks"
  end
end
