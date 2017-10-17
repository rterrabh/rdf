module Paperclip
  module Shoulda
    module Matchers
      def validate_attachment_size name
        ValidateAttachmentSizeMatcher.new(name)
      end

      class ValidateAttachmentSizeMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
        end

        def less_than size
          @high = size
          self
        end

        def greater_than size
          @low = size
          self
        end

        def in range
          @low, @high = range.first, range.last
          self
        end

        def matches? subject
          @subject = subject
          @subject = @subject.new if @subject.class == Class
          lower_than_low? && higher_than_low? && lower_than_high? && higher_than_high?
        end

        def failure_message
          "Attachment #{@attachment_name} must be between #{@low} and #{@high} bytes"
        end

        def failure_message_when_negated
          "Attachment #{@attachment_name} cannot be between #{@low} and #{@high} bytes"
        end
        alias negative_failure_message failure_message_when_negated

        def description
          "validate the size of attachment #{@attachment_name}"
        end

        protected

        def override_method object, method, &replacement
          #nodyna <class_eval-681> <CE MODERATE (define methods)>
          (class << object; self; end).class_eval do
            #nodyna <define_method-682> <DM MODERATE (events)>
            define_method(method, &replacement)
          end
        end

        def passes_validation_with_size(new_size)
          file = StringIO.new(".")
          override_method(file, :size){ new_size }
          override_method(file, :to_tempfile){ file }

          #nodyna <send-683> <SD COMPLEX (change-prone variables)>
          @subject.send(@attachment_name).post_processing = false
          #nodyna <send-684> <SD COMPLEX (change-prone variables)>
          @subject.send(@attachment_name).assign(file)
          @subject.valid?
          @subject.errors[:"#{@attachment_name}_file_size"].blank?
        ensure
          #nodyna <send-685> <SD COMPLEX (change-prone variables)>
          @subject.send(@attachment_name).post_processing = true
        end

        def lower_than_low?
          @low.nil? || !passes_validation_with_size(@low - 1)
        end

        def higher_than_low?
          @low.nil? || passes_validation_with_size(@low + 1)
        end

        def lower_than_high?
          @high.nil? || @high == Float::INFINITY || passes_validation_with_size(@high - 1)
        end

        def higher_than_high?
          @high.nil? || @high == Float::INFINITY || !passes_validation_with_size(@high + 1)
        end
      end
    end
  end
end
