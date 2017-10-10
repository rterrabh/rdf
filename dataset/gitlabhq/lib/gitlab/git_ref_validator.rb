module Gitlab
  module GitRefValidator
    extend self
    def validate(ref_name)
      Gitlab::Utils.system_silent(
        %W(git check-ref-format refs/#{ref_name}))
    end
  end
end
