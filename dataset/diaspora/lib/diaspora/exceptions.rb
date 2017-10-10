
module Diaspora
  class NonPublic < StandardError
  end

  class AccountClosed < StandardError
  end

  class NotMine < StandardError
  end

  class ContactRequiredUnlessRequest < StandardError
  end

  class RelayableObjectWithoutParent < StandardError
  end

  class AuthorXMLAuthorMismatch < StandardError
  end

  class PostNotFetchable < StandardError
  end

  class XMLNotParseable < StandardError
  end
end
