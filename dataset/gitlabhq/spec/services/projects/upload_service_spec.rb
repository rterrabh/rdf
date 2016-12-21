require 'spec_helper'

describe Projects::UploadService do
  describe 'File service' do
    before do
      @user = create :user
      @project = create :project, creator_id: @user.id, namespace: @user.namespace
    end

    context 'for valid gif file' do
      before do
        gif = fixture_file_upload(Rails.root + 'spec/fixtures/banana_sample.gif', 'image/gif')
        @link_to_file = upload_file(@project.repository, gif)
      end

      it { expect(@link_to_file).to have_key('alt') }
      it { expect(@link_to_file).to have_key('url') }
      it { expect(@link_to_file).to have_key('is_image') }
      it { expect(@link_to_file).to have_value('banana_sample') }
      it { expect(@link_to_file['is_image']).to equal(true) }
      it { expect(@link_to_file['url']).to match("/#{@project.path_with_namespace}") }
      it { expect(@link_to_file['url']).to match('banana_sample.gif') }
    end

    context 'for valid png file' do
      before do
        png = fixture_file_upload(Rails.root + 'spec/fixtures/dk.png',
          'image/png')
        @link_to_file = upload_file(@project.repository, png)
      end

      it { expect(@link_to_file).to have_key('alt') }
      it { expect(@link_to_file).to have_key('url') }
      it { expect(@link_to_file).to have_value('dk') }
      it { expect(@link_to_file).to have_key('is_image') }
      it { expect(@link_to_file['is_image']).to equal(true) }
      it { expect(@link_to_file['url']).to match("/#{@project.path_with_namespace}") }
      it { expect(@link_to_file['url']).to match('dk.png') }
    end

    context 'for valid jpg file' do
      before do
        jpg = fixture_file_upload(Rails.root + 'spec/fixtures/rails_sample.jpg', 'image/jpg')
        @link_to_file = upload_file(@project.repository, jpg)
      end

      it { expect(@link_to_file).to have_key('alt') }
      it { expect(@link_to_file).to have_key('url') }
      it { expect(@link_to_file).to have_key('is_image') }
      it { expect(@link_to_file).to have_value('rails_sample') }
      it { expect(@link_to_file['is_image']).to equal(true) }
      it { expect(@link_to_file['url']).to match("/#{@project.path_with_namespace}") }
      it { expect(@link_to_file['url']).to match('rails_sample.jpg') }
    end

    context 'for txt file' do
      before do
        txt = fixture_file_upload(Rails.root + 'spec/fixtures/doc_sample.txt', 'text/plain')
        @link_to_file = upload_file(@project.repository, txt)
      end

      it { expect(@link_to_file).to have_key('alt') }
      it { expect(@link_to_file).to have_key('url') }
      it { expect(@link_to_file).to have_key('is_image') }
      it { expect(@link_to_file).to have_value('doc_sample.txt') }
      it { expect(@link_to_file['is_image']).to equal(false) }
      it { expect(@link_to_file['url']).to match("/#{@project.path_with_namespace}") }
      it { expect(@link_to_file['url']).to match('doc_sample.txt') }
    end

    context 'for too large a file' do
      before do
        txt = fixture_file_upload(Rails.root + 'spec/fixtures/doc_sample.txt', 'text/plain')
        allow(txt).to receive(:size) { 1000.megabytes.to_i }
        @link_to_file = upload_file(@project.repository, txt)
      end

      it { expect(@link_to_file).to eq(nil) }
    end
  end

  def upload_file(repository, file)
    Projects::UploadService.new(repository, file).execute
  end
end
