module WikiHelper
  def namespace_project_wiki_path(namespace, project, wiki_page, *args)
    slug =
        case wiki_page
        when Symbol
          wiki_page
        when String
          wiki_page
        else
          wiki_page.slug
        end
    namespace_project_path(namespace, project) + "/wikis/#{slug}"
  end

  def edit_namespace_project_wiki_path(namespace, project, wiki_page, *args)
    namespace_project_wiki_path(namespace, project, wiki_page) + '/edit'
  end

  def history_namespace_project_wiki_path(namespace, project, wiki_page, *args)
    namespace_project_wiki_path(namespace, project, wiki_page) + '/history'
  end
end
