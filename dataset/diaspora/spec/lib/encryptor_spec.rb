
require 'spec_helper'

describe 'user encryption' do
  before do
    @user = alice
    @aspect = @user.aspects.first
  end

  describe 'encryption' do
    it 'should encrypt a string' do
      string = "Secretsauce"
      ciphertext = @user.person.encrypt string
      expect(ciphertext.include?(string)).to be false
      expect(@user.decrypt(ciphertext)).to eq(string)
    end
  end
end
