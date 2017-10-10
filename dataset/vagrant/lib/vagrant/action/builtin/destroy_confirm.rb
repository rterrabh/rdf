require_relative "confirm"

module Vagrant
  module Action
    module Builtin
      class DestroyConfirm < Confirm
        def initialize(app, env)
          force_key = :force_confirm_destroy
          message   = I18n.t("vagrant.commands.destroy.confirmation",
                             name: env[:machine].name)

          super(app, env, message, force_key, allowed: ["y", "n", "Y", "N"])
        end
      end
    end
  end
end
