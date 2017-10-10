
class CiService < Service
  def category
    :ci
  end

  def supported_events
    %w(push)
  end

  def build_page(sha, ref)
  end

  def commit_status(sha, ref)
  end
end
