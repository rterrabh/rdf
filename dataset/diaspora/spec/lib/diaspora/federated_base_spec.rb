
require 'spec_helper'

describe Diaspora::Federated::Base do
  describe '#subscribers' do
    it 'throws an error if the including module does not redefine it' do
      class Foo
        include Diaspora::Federated::Base 
      end

      f = Foo.new

      expect{ f.subscribers(1)}.to raise_error /override subscribers/
    end
  end
end
