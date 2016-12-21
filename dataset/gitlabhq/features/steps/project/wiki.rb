class Spinach::Features::ProjectWiki < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedProject
  include SharedNote
  include SharedPaths
  include WikiHelper

  step 'I click on the Cancel button' do
    page.within(:css, ".form-actions") do
      click_on "Cancel"
    end
  end

  step 'I should be redirected back to the Edit Home Wiki page' do
    expect(current_path).to eq namespace_project_wiki_path(project.namespace, project, :home)
  end

  step 'I create the Wiki Home page' do
    fill_in "wiki_content", with: '[link test](test)'
    click_on "Create page"
  end

  step 'I should see the newly created wiki page' do
    expect(page).to have_content "Home"
    expect(page).to have_content "link test"

    click_link "link test"
    expect(page).to have_content "Editing"
  end

  step 'I have an existing Wiki page' do
    wiki.create_page("existing", "content", :markdown, "first commit")
    @page = wiki.find_page("existing")
  end

  step 'I browse to that Wiki page' do
    visit namespace_project_wiki_path(project.namespace, project, @page)
  end

  step 'I click on the Edit button' do
    click_on "Edit"
  end

  step 'I change the content' do
    fill_in "Content", with: 'Updated Wiki Content'
    click_on "Save changes"
  end

  step 'I should see the updated content' do
    expect(page).to have_content "Updated Wiki Content"
  end

  step 'I should be redirected back to that Wiki page' do
    expect(current_path).to eq namespace_project_wiki_path(project.namespace, project, @page)
  end

  step 'That page has two revisions' do
    @page.update("new content", :markdown, "second commit")
  end

  step 'I click the History button' do
    click_on "History"
  end

  step 'I should see both revisions' do
    expect(page).to have_content current_user.name
    expect(page).to have_content "first commit"
    expect(page).to have_content "second commit"
  end

  step 'I click on the "Delete this page" button' do
    click_on "Delete this page"
  end

  step 'The page should be deleted' do
    expect(page).to have_content "Page was successfully deleted"
  end

  step 'I click on the "Pages" button' do
    click_on "Pages"
  end

  step 'I should see the existing page in the pages list' do
    expect(page).to have_content current_user.name
    expect(page).to have_content @page.title
  end

  step 'I have an existing Wiki page with images linked on page' do
    wiki.create_page("pictures", "Look at this [image](image.jpg)\n\n ![image](image.jpg)", :markdown, "first commit")
    @wiki_page = wiki.find_page("pictures")
  end

  step 'I browse to wiki page with images' do
    visit namespace_project_wiki_path(project.namespace, project, @wiki_page)
  end

  step 'I click on existing image link' do
    file = Gollum::File.new(wiki.wiki)
    Gollum::Wiki.any_instance.stub(:file).with("image.jpg", "master", true).and_return(file)
    Gollum::File.any_instance.stub(:mime_type).and_return("image/jpeg")
    expect(page).to have_link('image', href: "image.jpg")
    click_on "image"
  end

  step 'I should see the image from wiki repo' do
    expect(current_path).to match('wikis/image.jpg')
    expect(page).not_to have_xpath('/html') # Page should render the image which means there is no html involved
    Gollum::Wiki.any_instance.unstub(:file)
    Gollum::File.any_instance.unstub(:mime_type)
  end

  step 'Image should be shown on the page' do
    expect(page).to have_xpath("//img[@src=\"image.jpg\"]")
  end

  step 'I click on image link' do
    expect(page).to have_link('image', href: "image.jpg")
    click_on "image"
  end

  step 'I should see the new wiki page form' do
    expect(current_path).to match('wikis/image.jpg')
    expect(page).to have_content('New Wiki Page')
    expect(page).to have_content('Editing - image.jpg')
  end

  step 'I create a New page with paths' do
    click_on 'New Page'
    fill_in 'Page slug', with: 'one/two/three'
    click_on 'Build'
    fill_in "wiki_content", with: 'wiki content'
    click_on "Create page"
    expect(current_path).to include 'one/two/three'
  end

  step 'I create a New page with an invalid name' do
    click_on 'New Page'
    fill_in 'Page slug', with: 'invalid name'
    click_on 'Build'
  end

  step 'I should see an error message' do
    expect(page).to have_content "The page slug is invalid"
  end

  step 'I should see non-escaped link in the pages list' do
    expect(page).to have_xpath("//a[@href='/#{project.path_with_namespace}/wikis/one/two/three']")
  end

  step 'I edit the Wiki page with a path' do
    click_on 'three'
    click_on 'Edit'
  end

  step 'I should see a non-escaped path' do
    expect(current_path).to include 'one/two/three'
  end

  step 'I should see the Editing page' do
    expect(page).to have_content('Editing')
  end

  step 'I view the page history of a Wiki page that has a path' do
    click_on 'three'
    click_on 'Page History'
  end

  step 'I should see the page history' do
    expect(page).to have_content('History for')
  end

  step 'I search for Wiki content' do
    fill_in "Search in this project", with: "wiki_content"
    click_button "Search"
  end

  def wiki
    @project_wiki = ProjectWiki.new(project, current_user)
  end
end
