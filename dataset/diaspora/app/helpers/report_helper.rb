
module ReportHelper
  def report_content(id, type)
    if type == 'post' && !(post = Post.find_by_id(id)).nil?
      raw t('report.post_label', title: link_to(post_page_title(post), post_path(id)))
    elsif type == 'comment' && !(comment = Comment.find_by_id(id)).nil?
      raw t('report.comment_label', data: link_to(h(comment_message(comment)), post_path(comment.post.id, anchor: comment.guid)))
    else
      raw t('report.not_found')
    end
  end
end
