# == Schema Information
#
# Table name: snippets
#
#  id               :integer          not null, primary key
#  title            :string(255)
#  content          :text
#  author_id        :integer          not null
#  project_id       :integer
#  created_at       :datetime
#  updated_at       :datetime
#  file_name        :string(255)
#  expires_at       :datetime
#  type             :string(255)
#  visibility_level :integer          default(0), not null
#

require 'spec_helper'

describe Snippet do
  describe 'modules' do
    subject { described_class }

    it { is_expected.to include_module(Gitlab::VisibilityLevel) }
    it { is_expected.to include_module(Linguist::BlobHelper) }
    it { is_expected.to include_module(Participable) }
    it { is_expected.to include_module(Referable) }
    it { is_expected.to include_module(Sortable) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:author).class_name('User') }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:notes).dependent(:destroy) }
  end

  describe 'validation' do
    it { is_expected.to validate_presence_of(:author) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_within(0..255) }

    it { is_expected.to validate_length_of(:file_name).is_within(0..255) }

    it { is_expected.to validate_presence_of(:content) }

    it { is_expected.to validate_inclusion_of(:visibility_level).in_array(Gitlab::VisibilityLevel.values) }
  end

  describe '#to_reference' do
    let(:project) { create(:empty_project) }
    let(:snippet) { create(:snippet, project: project) }

    it 'returns a String reference to the object' do
      expect(snippet.to_reference).to eq "$#{snippet.id}"
    end

    it 'supports a cross-project reference' do
      cross = double('project')
      expect(snippet.to_reference(cross)).to eq "#{project.to_reference}$#{snippet.id}"
    end
  end
end
