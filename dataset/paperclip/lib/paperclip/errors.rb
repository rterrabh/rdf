module Paperclip
  class Error < StandardError
  end

  module Errors
    class StorageMethodNotFound < Paperclip::Error
    end

    class CommandNotFoundError < Paperclip::Error
    end

    class MissingRequiredValidatorError < Paperclip::Error
    end

    class NotIdentifiedByImageMagickError < Paperclip::Error
    end

    class InfiniteInterpolationError < Paperclip::Error
    end
  end
end
