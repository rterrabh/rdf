module IRB # :nodoc:
  module ExtendCommandBundle
    EXCB = ExtendCommandBundle # :nodoc:

    NO_OVERRIDE = 0
    OVERRIDE_PRIVATE_ONLY = 0x01
    OVERRIDE_ALL = 0x02

    def irb_exit(ret = 0)
      irb_context.exit(ret)
    end

    def irb_context
      IRB.CurrentContext
    end

    @ALIASES = [
      [:context, :irb_context, NO_OVERRIDE],
      [:conf, :irb_context, NO_OVERRIDE],
      [:irb_quit, :irb_exit, OVERRIDE_PRIVATE_ONLY],
      [:exit, :irb_exit, OVERRIDE_PRIVATE_ONLY],
      [:quit, :irb_exit, OVERRIDE_PRIVATE_ONLY],
    ]

    @EXTEND_COMMANDS = [
      [:irb_current_working_workspace, :CurrentWorkingWorkspace, "irb/cmd/chws",
       [:irb_print_working_workspace, OVERRIDE_ALL],
       [:irb_cwws, OVERRIDE_ALL],
       [:irb_pwws, OVERRIDE_ALL],
       [:cwws, NO_OVERRIDE],
       [:pwws, NO_OVERRIDE],
       [:irb_current_working_binding, OVERRIDE_ALL],
       [:irb_print_working_binding, OVERRIDE_ALL],
       [:irb_cwb, OVERRIDE_ALL],
       [:irb_pwb, OVERRIDE_ALL],
    ],
    [:irb_change_workspace, :ChangeWorkspace, "irb/cmd/chws",
     [:irb_chws, OVERRIDE_ALL],
     [:irb_cws, OVERRIDE_ALL],
     [:chws, NO_OVERRIDE],
     [:cws, NO_OVERRIDE],
     [:irb_change_binding, OVERRIDE_ALL],
     [:irb_cb, OVERRIDE_ALL],
     [:cb, NO_OVERRIDE]],

    [:irb_workspaces, :Workspaces, "irb/cmd/pushws",
     [:workspaces, NO_OVERRIDE],
     [:irb_bindings, OVERRIDE_ALL],
     [:bindings, NO_OVERRIDE]],
    [:irb_push_workspace, :PushWorkspace, "irb/cmd/pushws",
     [:irb_pushws, OVERRIDE_ALL],
     [:pushws, NO_OVERRIDE],
     [:irb_push_binding, OVERRIDE_ALL],
     [:irb_pushb, OVERRIDE_ALL],
     [:pushb, NO_OVERRIDE]],
    [:irb_pop_workspace, :PopWorkspace, "irb/cmd/pushws",
     [:irb_popws, OVERRIDE_ALL],
     [:popws, NO_OVERRIDE],
     [:irb_pop_binding, OVERRIDE_ALL],
     [:irb_popb, OVERRIDE_ALL],
     [:popb, NO_OVERRIDE]],

    [:irb_load, :Load, "irb/cmd/load"],
    [:irb_require, :Require, "irb/cmd/load"],
    [:irb_source, :Source, "irb/cmd/load",
     [:source, NO_OVERRIDE]],

    [:irb, :IrbCommand, "irb/cmd/subirb"],
    [:irb_jobs, :Jobs, "irb/cmd/subirb",
     [:jobs, NO_OVERRIDE]],
    [:irb_fg, :Foreground, "irb/cmd/subirb",
     [:fg, NO_OVERRIDE]],
    [:irb_kill, :Kill, "irb/cmd/subirb",
     [:kill, OVERRIDE_PRIVATE_ONLY]],

    [:irb_help, :Help, "irb/cmd/help",
     [:help, NO_OVERRIDE]],

    ]

    def self.install_extend_commands
      for args in @EXTEND_COMMANDS
        def_extend_command(*args)
      end
    end

    def self.def_extend_command(cmd_name, cmd_class, load_file = nil, *aliases)
      case cmd_class
      when Symbol
        cmd_class = cmd_class.id2name
      when String
      when Class
        cmd_class = cmd_class.name
      end

      if load_file
        #nodyna <eval-2207> <EV MODERATE (method definition)>
        line = __LINE__; eval %[
          def #{cmd_name}(*opts, &b)
            require "#{load_file}"
            arity = ExtendCommand::#{cmd_class}.instance_method(:execute).arity
            args = (1..(arity < 0 ? ~arity : arity)).map {|i| "arg" + i.to_s }
            args << "*opts" if arity < 0
            args << "&block"
            args = args.join(", ")
            #nodyna <eval-2208> <EV MODERATE (method definition)>
            line = __LINE__; eval %[
              def #{cmd_name}(\#{args})
            ExtendCommand::#{cmd_class}.execute(irb_context, \#{args})
              end
            ], nil, __FILE__, line
            #nodyna <send-2209> <SD MODERATE (change-prone variable)>
            send :#{cmd_name}, *opts, &b
          end
        ], nil, __FILE__, line
      else
        #nodyna <eval-2210> <EV MODERATE (method definition)>
        line = __LINE__; eval %[
          def #{cmd_name}(*opts, &b)
            ExtendCommand::#{cmd_class}.execute(irb_context, *opts, &b)
          end
        ], nil, __FILE__, line
      end

      for ali, flag in aliases
        @ALIASES.push [ali, cmd_name, flag]
      end
    end

    def install_alias_method(to, from, override = NO_OVERRIDE)
      to = to.id2name unless to.kind_of?(String)
      from = from.id2name unless from.kind_of?(String)

      if override == OVERRIDE_ALL or
          (override == OVERRIDE_PRIVATE_ONLY) && !respond_to?(to) or
          (override == NO_OVERRIDE) &&  !respond_to?(to, true)
        target = self
        #nodyna <instance_eval-2211> <IEV MODERATE (private access)>
        (class << self; self; end).instance_eval{
          if target.respond_to?(to, true) &&
            !target.respond_to?(EXCB.irb_original_method_name(to), true)
            alias_method(EXCB.irb_original_method_name(to), to)
          end
          alias_method to, from
        }
      else
        print "irb: warn: can't alias #{to} from #{from}.\n"
      end
    end

    def self.irb_original_method_name(method_name) # :nodoc:
      "irb_" + method_name + "_org"
    end

    def self.extend_object(obj)
      unless (class << obj; ancestors; end).include?(EXCB)
        super
        for ali, com, flg in @ALIASES
          obj.install_alias_method(ali, com, flg)
        end
      end
    end

    install_extend_commands
  end

  module ContextExtender
    CE = ContextExtender # :nodoc:

    @EXTEND_COMMANDS = [
      [:eval_history=, "irb/ext/history.rb"],
      [:use_tracer=, "irb/ext/tracer.rb"],
      [:math_mode=, "irb/ext/math-mode.rb"],
      [:use_loader=, "irb/ext/use-loader.rb"],
      [:save_history=, "irb/ext/save-history.rb"],
    ]

    def self.install_extend_commands
      for args in @EXTEND_COMMANDS
        def_extend_command(*args)
      end
    end

    def self.def_extend_command(cmd_name, load_file, *aliases)
      #nodyna <module_eval-2212> <ME COMPLEX (define methods)>
      line = __LINE__; Context.module_eval %[
        def #{cmd_name}(*opts, &b)
          #nodyna <module_eval-2213> <ME MODERATE (block execution)>
          Context.module_eval {remove_method(:#{cmd_name})}
          require "#{load_file}"
          #nodyna <send-2214> <SD MODERATE (change-prone variable)>
          send :#{cmd_name}, *opts, &b
        end
        for ali in aliases
          alias_method ali, cmd_name
        end
      ], __FILE__, line
    end

    CE.install_extend_commands
  end

  module MethodExtender
    def def_pre_proc(base_method, extend_method)
      base_method = base_method.to_s
      extend_method = extend_method.to_s

      alias_name = new_alias_name(base_method)
      #nodyna <module_eval-2215> <ME COMPLEX (define methods)>
      module_eval %[
        alias_method alias_name, base_method
        def #{base_method}(*opts)
          #nodyna <send-2216> <SD>
          send :#{extend_method}, *opts
          #nodyna <send-2217> <SD COMPLEX (change-prone variable)>
          send :#{alias_name}, *opts
        end
      ]
    end

    def def_post_proc(base_method, extend_method)
      base_method = base_method.to_s
      extend_method = extend_method.to_s

      alias_name = new_alias_name(base_method)
      #nodyna <module_eval-2218> <ME COMPLEX (define methods)>
      module_eval %[
        alias_method alias_name, base_method
        def #{base_method}(*opts)
          #nodyna <send-2219> <SD COMPLEX (change-prone variable)>
          send :#{alias_name}, *opts
          #nodyna <send-2220> <SD COMPLEX (change-prone variable)>
          send :#{extend_method}, *opts
        end
      ]
    end

    def new_alias_name(name, prefix = "__alias_of__", postfix = "__")
      base_name = "#{prefix}#{name}#{postfix}"
      all_methods = instance_methods(true) + private_instance_methods(true)
      same_methods = all_methods.grep(/^#{Regexp.quote(base_name)}[0-9]*$/)
      return base_name if same_methods.empty?
      no = same_methods.size
      while !same_methods.include?(alias_name = base_name + no)
        no += 1
      end
      alias_name
    end
  end
end

