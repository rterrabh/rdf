require 'spec_helper'

describe 'Comments', feature: true do
  include RepoHelpers

  describe 'On a merge request', js: true, feature: true do
    let!(:merge_request) { create(:merge_request) }
    let!(:project) { merge_request.source_project }
    let!(:note) do
      create(:note_on_merge_request, :with_attachment, project: project)
    end

    before do
      login_as :admin
      visit namespace_project_merge_request_path(project.namespace, project, merge_request)
    end

    subject { page }

    describe 'the note form' do
      it 'should be valid' do
        is_expected.to have_css('.js-main-target-form', visible: true, count: 1)
        expect(find('.js-main-target-form input[type=submit]').value).
          to eq('Add Comment')
        page.within('.js-main-target-form') do
          expect(page).not_to have_link('Cancel')
        end
      end

      describe 'with text' do
        before do
          page.within('.js-main-target-form') do
            fill_in 'note[note]', with: 'This is awesome'
          end
        end

        it 'should have enable submit button and preview button' do
          page.within('.js-main-target-form') do
            expect(page).not_to have_css('.js-comment-button[disabled]')
            expect(page).to have_css('.js-md-preview-button', visible: true)
          end
        end
      end
    end

    describe 'when posting a note' do
      before do
        page.within('.js-main-target-form') do
          fill_in 'note[note]', with: 'This is awsome!'
          find('.js-md-preview-button').click
          click_button 'Add Comment'
        end
      end

      it 'should be added and form reset' do
        is_expected.to have_content('This is awsome!')
        page.within('.js-main-target-form') do
          expect(page).to have_no_field('note[note]', with: 'This is awesome!')
          expect(page).to have_css('.js-md-preview', visible: :hidden)
        end
        page.within('.js-main-target-form') do
          is_expected.to have_css('.js-note-text', visible: true)
        end
      end
    end

    describe 'when editing a note', js: true do
      it 'should contain the hidden edit form' do
        page.within("#note_#{note.id}") do
          is_expected.to have_css('.note-edit-form', visible: false)
        end
      end

      describe 'editing the note' do
        before do
          find('.note').hover
          find(".js-note-edit").click
        end

        it 'should show the note edit form and hide the note body' do
          page.within("#note_#{note.id}") do
            expect(find('.current-note-edit-form', visible: true)).to be_visible
            expect(find('.note-edit-form', visible: true)).to be_visible
            expect(find(:css, '.note-body > .note-text', visible: false)).not_to be_visible
          end
        end

        # TODO: fix after 7.7 release
        # it "should reset the edit note form textarea with the original content of the note if cancelled" do
        #   within(".current-note-edit-form") do
        #     fill_in "note[note]", with: "Some new content"
        #     find(".btn-cancel").click
        #     expect(find(".js-note-text", visible: false).text).to eq note.note
        #   end
        # end

        it 'appends the edited at time to the note' do
          page.within('.current-note-edit-form') do
            fill_in 'note[note]', with: 'Some new content'
            find('.btn-save').click
          end

          page.within("#note_#{note.id}") do
            is_expected.to have_css('.note_edited_ago')
            expect(find('.note_edited_ago').text).
              to match(/less than a minute ago/)
          end
        end
      end

      describe 'deleting an attachment' do
        before do
          find('.note').hover
          find('.js-note-edit').click
        end

        it 'shows the delete link' do
          page.within('.note-attachment') do
            is_expected.to have_css('.js-note-attachment-delete')
          end
        end

        it 'removes the attachment div and resets the edit form' do
          find('.js-note-attachment-delete').click
          is_expected.not_to have_css('.note-attachment')
          expect(find('.current-note-edit-form', visible: false)).
            not_to be_visible
        end
      end
    end
  end

  describe 'On a merge request diff', js: true, feature: true do
    let(:merge_request) { create(:merge_request) }
    let(:project) { merge_request.source_project }

    before do
      login_as :admin
      visit diffs_namespace_project_merge_request_path(project.namespace, project, merge_request)
    end

    subject { page }

    describe 'when adding a note' do
      before do
        click_diff_line
      end

      describe 'the notes holder' do
        it { is_expected.to have_css('.js-temp-notes-holder') }

        it 'has .new_note css class' do
          page.within('.js-temp-notes-holder') do
            expect(subject).to have_css('.new_note')
          end
        end
      end

      describe 'the note form' do
        it "shouldn't add a second form for same row" do
          click_diff_line

          is_expected.
            to have_css("tr[id='#{line_code}'] + .js-temp-notes-holder form",
                        count: 1)
        end

        it 'should be removed when canceled' do
          page.within(".diff-file form[rel$='#{line_code}']") do
            find('.js-close-discussion-note-form').trigger('click')
          end

          is_expected.to have_no_css('.js-temp-notes-holder')
        end
      end
    end

    describe 'with muliple note forms' do
      before do
        click_diff_line
        click_diff_line(line_code_2)
      end

      it { is_expected.to have_css('.js-temp-notes-holder', count: 2) }

      describe 'previewing them separately' do
        before do
          # add two separate texts and trigger previews on both
          page.within("tr[id='#{line_code}'] + .js-temp-notes-holder") do
            fill_in 'note[note]', with: 'One comment on line 7'
            find('.js-md-preview-button').click
          end
          page.within("tr[id='#{line_code_2}'] + .js-temp-notes-holder") do
            fill_in 'note[note]', with: 'Another comment on line 10'
            find('.js-md-preview-button').click
          end
        end
      end

      describe 'posting a note' do
        before do
          page.within("tr[id='#{line_code_2}'] + .js-temp-notes-holder") do
            fill_in 'note[note]', with: 'Another comment on line 10'
            click_button('Add Comment')
          end
        end

        it 'should be added as discussion' do
          is_expected.to have_content('Another comment on line 10')
          is_expected.to have_css('.notes_holder')
          is_expected.to have_css('.notes_holder .note', count: 1)
          is_expected.to have_button('Reply')
        end
      end
    end
  end

  def line_code
    sample_compare.changes.first[:line_code]
  end

  def line_code_2
    sample_compare.changes.last[:line_code]
  end

  def click_diff_line(data = line_code)
    page.find(%Q{button[data-line-code="#{data}"]}, visible: false).click
  end
end
