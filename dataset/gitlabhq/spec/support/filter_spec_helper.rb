# Helper methods for Gitlab::Markdown filter specs
#
# Must be included into specs manually
module FilterSpecHelper
  extend ActiveSupport::Concern

  # Perform `call` on the described class
  #
  # Automatically passes the current `project` value, if defined, to the context
  # if none is provided.
  #
  # html     - HTML String to pass to the filter's `call` method.
  # contexts - Hash context for the filter. (default: {project: project})
  #
  # Returns a Nokogiri::XML::DocumentFragment
  def filter(html, contexts = {})
    if defined?(project)
      contexts.reverse_merge!(project: project)
    end

    described_class.call(html, contexts)
  end

  # Run text through HTML::Pipeline with the current filter and return the
  # result Hash
  #
  # body     - String text to run through the pipeline
  # contexts - Hash context for the filter. (default: {project: project})
  #
  # Returns the Hash
  def pipeline_result(body, contexts = {})
    contexts.reverse_merge!(project: project)

    pipeline = HTML::Pipeline.new([described_class], contexts)
    pipeline.call(body)
  end

  # Modify a String reference to make it invalid
  #
  # Commit SHAs get reversed, IDs get incremented by 1, all other Strings get
  # their word characters reversed.
  #
  # reference - String reference to modify
  #
  # Returns a String
  def invalidate_reference(reference)
    if reference =~ /\A(.+)?.\d+\z/
      # Integer-based reference with optional project prefix
      reference.gsub(/\d+\z/) { |i| i.to_i + 1 }
    elsif reference =~ /\A(.+@)?(\h{6,40}\z)/
      # SHA-based reference with optional prefix
      reference.gsub(/\h{6,40}\z/) { |v| v.reverse }
    else
      reference.gsub(/\w+\z/) { |v| v.reverse }
    end
  end

  # Stub CrossProjectReference#user_can_reference_project? to return true for
  # the current test
  def allow_cross_reference!
    allow_any_instance_of(described_class).
      to receive(:user_can_reference_project?).and_return(true)
  end

  # Stub CrossProjectReference#user_can_reference_project? to return false for
  # the current test
  def disallow_cross_reference!
    allow_any_instance_of(described_class).
      to receive(:user_can_reference_project?).and_return(false)
  end

  # Shortcut to Rails' auto-generated routes helpers, to avoid including the
  # module
  def urls
    Rails.application.routes.url_helpers
  end
end
