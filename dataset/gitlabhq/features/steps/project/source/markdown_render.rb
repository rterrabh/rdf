# If you need to modify the existing seed repository for your tests,
# it is recommended that you make the changes on the `markdown` branch of the seed project repository,
# which should only be used by tests in this file. See `/spec/factories.rb#project` for more info.
class Spinach::Features::ProjectSourceMarkdownRender < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedPaths
  include SharedMarkdown

  step 'I own project "Delta"' do
    @project = Project.find_by(name: "Delta")
    @project ||= create(:project, name: "Delta", namespace: @user.namespace)
    @project.team << [@user, :master]
  end

  step 'I should see files from repository in markdown' do
    expect(current_path).to eq namespace_project_tree_path(@project.namespace, @project, "markdown")
    expect(page).to have_content "README.md"
    expect(page).to have_content "CHANGELOG"
  end

  step 'I should see rendered README which contains correct links' do
    expect(page).to have_content "Welcome to GitLab GitLab is a free project and repository management application"
    expect(page).to have_link "GitLab API doc"
    expect(page).to have_link "GitLab API website"
    expect(page).to have_link "Rake tasks"
    expect(page).to have_link "backup and restore procedure"
    expect(page).to have_link "GitLab API doc directory"
    expect(page).to have_link "Maintenance"
  end

  step 'I click on Gitlab API in README' do
    click_link "GitLab API doc"
  end

  step 'I should see correct document rendered' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/api/README.md")
    expect(page).to have_content "All API requests require authentication"
  end

  step 'I click on Rake tasks in README' do
    click_link "Rake tasks"
  end

  step 'I should see correct directory rendered' do
    expect(current_path).to eq namespace_project_tree_path(@project.namespace, @project, "markdown/doc/raketasks")
    expect(page).to have_content "backup_restore.md"
    expect(page).to have_content "maintenance.md"
  end

  step 'I click on GitLab API doc directory in README' do
    click_link "GitLab API doc directory"
  end

  step 'I should see correct doc/api directory rendered' do
    expect(current_path).to eq namespace_project_tree_path(@project.namespace, @project, "markdown/doc/api")
    expect(page).to have_content "README.md"
    expect(page).to have_content "users.md"
  end

  step 'I click on Maintenance in README' do
    click_link "Maintenance"
  end

  step 'I should see correct maintenance file rendered' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/raketasks/maintenance.md")
    expect(page).to have_content "bundle exec rake gitlab:env:info RAILS_ENV=production"
  end

  step 'I click on link "empty" in the README' do
    page.within('.readme-holder') do
      click_link "empty"
    end
  end

  step 'I click on link "id" in the README' do
    page.within('.readme-holder') do
      click_link "#id"
    end
  end

  step 'I navigate to the doc/api/README' do
    page.within '.tree-table' do
      click_link "doc"
    end

    page.within '.tree-table' do
      click_link "api"
    end

    page.within '.tree-table' do
      click_link "README.md"
    end
  end

  step 'I see correct file rendered' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/api/README.md")
    expect(page).to have_content "Contents"
    expect(page).to have_link "Users"
    expect(page).to have_link "Rake tasks"
  end

  step 'I click on users in doc/api/README' do
    click_link "Users"
  end

  step 'I should see the correct document file' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/api/users.md")
    expect(page).to have_content "Get a list of users."
  end

  step 'I click on raketasks in doc/api/README' do
    click_link "Rake tasks"
  end

  # Markdown branch

  When 'I visit markdown branch' do
    visit namespace_project_tree_path(@project.namespace, @project, "markdown")
  end

  When 'I visit markdown branch "README.md" blob' do
    visit namespace_project_blob_path(@project.namespace, @project, "markdown/README.md")
  end

  When 'I visit markdown branch "d" tree' do
    visit namespace_project_tree_path(@project.namespace, @project, "markdown/d")
  end

  When 'I visit markdown branch "d/README.md" blob' do
    visit namespace_project_blob_path(@project.namespace, @project, "markdown/d/README.md")
  end

  step 'I should see files from repository in markdown branch' do
    expect(current_path).to eq namespace_project_tree_path(@project.namespace, @project, "markdown")
    expect(page).to have_content "README.md"
    expect(page).to have_content "CHANGELOG"
  end

  step 'I see correct file rendered in markdown branch' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/api/README.md")
    expect(page).to have_content "Contents"
    expect(page).to have_link "Users"
    expect(page).to have_link "Rake tasks"
  end

  step 'I should see correct document rendered for markdown branch' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/api/README.md")
    expect(page).to have_content "All API requests require authentication"
  end

  step 'I should see correct directory rendered for markdown branch' do
    expect(current_path).to eq namespace_project_tree_path(@project.namespace, @project, "markdown/doc/raketasks")
    expect(page).to have_content "backup_restore.md"
    expect(page).to have_content "maintenance.md"
  end

  step 'I should see the users document file in markdown branch' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/api/users.md")
    expect(page).to have_content "Get a list of users."
  end

  # Expected link contents

  step 'The link with text "empty" should have url "tree/markdown"' do
    find('a', text: /^empty$/)['href'] == current_host + namespace_project_tree_path(@project.namespace, @project, "markdown")
  end

  step 'The link with text "empty" should have url "blob/markdown/README.md"' do
    find('a', text: /^empty$/)['href'] == current_host + namespace_project_blob_path(@project.namespace, @project, "markdown/README.md")
  end

  step 'The link with text "empty" should have url "tree/markdown/d"' do
    find('a', text: /^empty$/)['href'] == current_host + namespace_project_tree_path(@project.namespace, @project, "markdown/d")
  end

  step 'The link with text "empty" should have '\
       'url "blob/markdown/d/README.md"' do
    find('a', text: /^empty$/)['href'] == current_host + namespace_project_blob_path(@project.namespace, @project, "markdown/d/README.md")
  end

  step 'The link with text "ID" should have url "tree/markdownID"' do
    find('a', text: /^#id$/)['href'] == current_host + namespace_project_tree_path(@project.namespace, @project, "markdown") + '#id'
  end

  step 'The link with text "/ID" should have url "tree/markdownID"' do
    find('a', text: /^\/#id$/)['href'] == current_host + namespace_project_tree_path(@project.namespace, @project, "markdown") + '#id'
  end

  step 'The link with text "README.mdID" '\
       'should have url "blob/markdown/README.mdID"' do
    find('a', text: /^README.md#id$/)['href'] == current_host + namespace_project_blob_path(@project.namespace, @project, "markdown/README.md") + '#id'
  end

  step 'The link with text "d/README.mdID" should have '\
       'url "blob/markdown/d/README.mdID"' do
    find('a', text: /^d\/README.md#id$/)['href'] == current_host + namespace_project_blob_path(@project.namespace, @project, "d/markdown/README.md") + '#id'
  end

  step 'The link with text "ID" should have url "blob/markdown/README.mdID"' do
    find('a', text: /^#id$/)['href'] == current_host + namespace_project_blob_path(@project.namespace, @project, "markdown/README.md") + '#id'
  end

  step 'The link with text "/ID" should have url "blob/markdown/README.mdID"' do
    find('a', text: /^\/#id$/)['href'] == current_host + namespace_project_blob_path(@project.namespace, @project, "markdown/README.md") + '#id'
  end

  # Wiki

  step 'I go to wiki page' do
    click_link "Wiki"
    expect(current_path).to eq namespace_project_wiki_path(@project.namespace, @project, "home")
  end

  step 'I add various links to the wiki page' do
    fill_in "wiki[content]", with: "[test](test)\n[GitLab API doc](api)\n[Rake tasks](raketasks)\n"
    fill_in "wiki[message]", with: "Adding links to wiki"
    click_button "Create page"
  end

  step 'Wiki page should have added links' do
    expect(current_path).to eq namespace_project_wiki_path(@project.namespace, @project, "home")
    expect(page).to have_content "test GitLab API doc Rake tasks"
  end

  step 'I add a header to the wiki page' do
    fill_in "wiki[content]", with: "# Wiki header\n"
    fill_in "wiki[message]", with: "Add header to wiki"
    click_button "Create page"
  end

  step 'Wiki header should have correct id and link' do
    header_should_have_correct_id_and_link(1, 'Wiki header', 'wiki-header')
  end

  step 'I click on test link' do
    click_link "test"
  end

  step 'I see new wiki page named test' do
    expect(current_path).to eq  namespace_project_wiki_path(@project.namespace, @project, "test")
    expect(page).to have_content "Editing"
  end

  When 'I go back to wiki page home' do
    visit namespace_project_wiki_path(@project.namespace, @project, "home")
    expect(current_path).to eq namespace_project_wiki_path(@project.namespace, @project, "home")
  end

  step 'I click on GitLab API doc link' do
    click_link "GitLab API"
  end

  step 'I see Gitlab API document' do
    expect(current_path).to eq namespace_project_wiki_path(@project.namespace, @project, "api")
    expect(page).to have_content "Editing"
  end

  step 'I click on Rake tasks link' do
    click_link "Rake tasks"
  end

  step 'I see Rake tasks directory' do
    expect(current_path).to eq namespace_project_wiki_path(@project.namespace, @project, "raketasks")
    expect(page).to have_content "Editing"
  end

  step 'I go directory which contains README file' do
    visit namespace_project_tree_path(@project.namespace, @project, "markdown/doc/api")
    expect(current_path).to eq namespace_project_tree_path(@project.namespace, @project, "markdown/doc/api")
  end

  step 'I click on a relative link in README' do
    click_link "Users"
  end

  step 'I should see the correct markdown' do
    expect(current_path).to eq namespace_project_blob_path(@project.namespace, @project, "markdown/doc/api/users.md")
    expect(page).to have_content "List users"
  end

  step 'Header "Application details" should have correct id and link' do
    header_should_have_correct_id_and_link(2, 'Application details', 'application-details')
  end

  step 'Header "GitLab API" should have correct id and link' do
    header_should_have_correct_id_and_link(1, 'GitLab API', 'gitlab-api')
  end
end
