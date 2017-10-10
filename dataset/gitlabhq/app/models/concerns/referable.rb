module Referable
  extend ActiveSupport::Concern

  def to_reference(_from_project = nil)
    ''
  end

  module ClassMethods
    def reference_prefix
      ''
    end

    def reference_pattern
      raise NotImplementedError, "#{self} does not implement #{__method__}"
    end
  end

  private

  def cross_project_reference?(from_project)
    if self.is_a?(Project)
      self != from_project
    else
      from_project && self.project && self.project != from_project
    end
  end
end
