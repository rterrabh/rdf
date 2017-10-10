require 'html/pipeline'

module Gitlab
  module Markdown
    autoload :AutolinkFilter,               'gitlab/markdown/autolink_filter'
    autoload :CommitRangeReferenceFilter,   'gitlab/markdown/commit_range_reference_filter'
    autoload :CommitReferenceFilter,        'gitlab/markdown/commit_reference_filter'
    autoload :EmojiFilter,                  'gitlab/markdown/emoji_filter'
    autoload :ExternalIssueReferenceFilter, 'gitlab/markdown/external_issue_reference_filter'
    autoload :ExternalLinkFilter,           'gitlab/markdown/external_link_filter'
    autoload :IssueReferenceFilter,         'gitlab/markdown/issue_reference_filter'
    autoload :LabelReferenceFilter,         'gitlab/markdown/label_reference_filter'
    autoload :MergeRequestReferenceFilter,  'gitlab/markdown/merge_request_reference_filter'
    autoload :RelativeLinkFilter,           'gitlab/markdown/relative_link_filter'
    autoload :SanitizationFilter,           'gitlab/markdown/sanitization_filter'
    autoload :SnippetReferenceFilter,       'gitlab/markdown/snippet_reference_filter'
    autoload :TableOfContentsFilter,        'gitlab/markdown/table_of_contents_filter'
    autoload :TaskListFilter,               'gitlab/markdown/task_list_filter'
    autoload :UserReferenceFilter,          'gitlab/markdown/user_reference_filter'

    def gfm(text, options = {}, html_options = {})
      return text if text.nil?

      text = text.dup.to_str

      options.reverse_merge!(
        xhtml:                false,
        reference_only_path:  true,
        project:              @project,
        current_user:         current_user
      )

      @pipeline ||= HTML::Pipeline.new(filters)

      context = {
        pipeline: options[:pipeline],

        asset_root: Gitlab.config.gitlab.url,
        asset_host: Gitlab::Application.config.asset_host,

        no_header_anchors: options[:no_header_anchors],

        current_user:    options[:current_user],
        only_path:       options[:reference_only_path],
        project:         options[:project],
        reference_class: html_options[:class],

        ref:            @ref,
        requested_path: @path,
        project_wiki:   @project_wiki
      }

      result = @pipeline.call(text, context)

      save_options = 0
      if options[:xhtml]
        save_options |= Nokogiri::XML::Node::SaveOptions::AS_XHTML
      end

      text = result[:output].to_html(save_with: save_options)

      text.html_safe
    end

    private

    def filters
      [
        Gitlab::Markdown::SanitizationFilter,

        Gitlab::Markdown::RelativeLinkFilter,
        Gitlab::Markdown::EmojiFilter,
        Gitlab::Markdown::TableOfContentsFilter,
        Gitlab::Markdown::AutolinkFilter,
        Gitlab::Markdown::ExternalLinkFilter,

        Gitlab::Markdown::UserReferenceFilter,
        Gitlab::Markdown::IssueReferenceFilter,
        Gitlab::Markdown::ExternalIssueReferenceFilter,
        Gitlab::Markdown::MergeRequestReferenceFilter,
        Gitlab::Markdown::SnippetReferenceFilter,
        Gitlab::Markdown::CommitRangeReferenceFilter,
        Gitlab::Markdown::CommitReferenceFilter,
        Gitlab::Markdown::LabelReferenceFilter,

        Gitlab::Markdown::TaskListFilter
      ]
    end
  end
end
