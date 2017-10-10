module ActiveRecord
  module Callbacks
    extend ActiveSupport::Concern

    CALLBACKS = [
      :after_initialize, :after_find, :after_touch, :before_validation, :after_validation,
      :before_save, :around_save, :after_save, :before_create, :around_create,
      :after_create, :before_update, :around_update, :after_update,
      :before_destroy, :around_destroy, :after_destroy, :after_commit, :after_rollback
    ]

    module ClassMethods
      include ActiveModel::Callbacks
    end

    included do
      include ActiveModel::Validations::Callbacks

      define_model_callbacks :initialize, :find, :touch, :only => :after
      define_model_callbacks :save, :create, :update, :destroy
    end

    def destroy #:nodoc:
      _run_destroy_callbacks { super }
    end

    def touch(*) #:nodoc:
      _run_touch_callbacks { super }
    end

  private

    def create_or_update #:nodoc:
      _run_save_callbacks { super }
    end

    def _create_record #:nodoc:
      _run_create_callbacks { super }
    end

    def _update_record(*) #:nodoc:
      _run_update_callbacks { super }
    end
  end
end
