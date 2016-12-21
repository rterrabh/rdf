module SharedNote
  include Spinach::DSL

  step 'I delete a comment' do
    page.within('.notes') do
      find('.note').hover
      find(".js-note-delete").click
    end
  end

  step 'I haven\'t written any comment text' do
    page.within(".js-main-target-form") do
      fill_in "note[note]", with: ""
    end
  end

  step 'I leave a comment like "XML attached"' do
    page.within(".js-main-target-form") do
      fill_in "note[note]", with: "XML attached"
      click_button "Add Comment"
    end
  end

  step 'I preview a comment text like "Bug fixed :smile:"' do
    page.within(".js-main-target-form") do
      fill_in "note[note]", with: "Bug fixed :smile:"
      find('.js-md-preview-button').click
    end
  end

  step 'I submit the comment' do
    page.within(".js-main-target-form") do
      click_button "Add Comment"
    end
  end

  step 'I write a comment like ":+1: Nice"' do
    page.within(".js-main-target-form") do
      fill_in 'note[note]', with: ':+1: Nice'
    end
  end

  step 'I should not see a comment saying "XML attached"' do
    expect(page).not_to have_css(".note")
  end

  step 'I should not see the cancel comment button' do
    page.within(".js-main-target-form") do
      should_not have_link("Cancel")
    end
  end

  step 'I should not see the comment preview' do
    page.within(".js-main-target-form") do
      expect(find('.js-md-preview')).not_to be_visible
    end
  end

  step 'The comment preview tab should say there is nothing to do' do
    page.within(".js-main-target-form") do
      find('.js-md-preview-button').click
      expect(find('.js-md-preview')).to have_content('Nothing to preview.')
    end
  end

  step 'I should not see the comment text field' do
    page.within(".js-main-target-form") do
      expect(find('.js-note-text')).not_to be_visible
    end
  end

  step 'I should see a comment saying "XML attached"' do
    page.within(".note") do
      expect(page).to have_content("XML attached")
    end
  end

  step 'I should see an empty comment text field' do
    page.within(".js-main-target-form") do
      expect(page).to have_field("note[note]", with: "")
    end
  end

  step 'I should see the comment write tab' do
    page.within(".js-main-target-form") do
      expect(page).to have_css('.js-md-write-button', visible: true)
    end
  end

  step 'The comment preview tab should be display rendered Markdown' do
    page.within(".js-main-target-form") do
      find('.js-md-preview-button').click
      expect(find('.js-md-preview')).to have_css('img.emoji', visible: true)
    end
  end

  step 'I should see the comment preview' do
    page.within(".js-main-target-form") do
      expect(page).to have_css('.js-md-preview', visible: true)
    end
  end

  step 'I should see comment "XML attached"' do
    page.within(".note") do
      expect(page).to have_content("XML attached")
    end
  end

  # Markdown

  step 'I leave a comment with a header containing "Comment with a header"' do
    page.within(".js-main-target-form") do
      fill_in "note[note]", with: "# Comment with a header"
      click_button "Add Comment"
      sleep 0.05
    end
  end

  step 'The comment with the header should not have an ID' do
    page.within(".note-body > .note-text") do
      expect(page).to     have_content("Comment with a header")
      expect(page).not_to have_css("#comment-with-a-header")
    end
  end

  step 'I edit the last comment with a +1' do
    page.within(".notes") do
      find(".note").hover
      find('.js-note-edit').click
    end

    page.within(".current-note-edit-form") do
      fill_in 'note[note]', with: '+1 Awesome!'
      click_button 'Save Comment'
    end
  end

  step 'I should see +1 in the description' do
    page.within(".note") do
      expect(page).to have_content("+1 Awesome!")
    end
  end
end
