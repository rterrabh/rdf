require 'spec_helper'

module Grape
  module DSL
    module ParametersSpec
      class Dummy
        include Grape::DSL::Parameters
        attr_accessor :api, :element, :parent

        def validate_attributes(*args)
          @validate_attributes = *args
        end

        # rubocop:disable TrivialAccessors
        def validate_attributes_reader
          @validate_attributes
        end
        # rubocop:enable TrivialAccessors

        def push_declared_params(*args)
          @push_declared_params = args
        end

        # rubocop:disable TrivialAccessors
        def push_declared_params_reader
          @push_declared_params
        end
        # rubocop:enable TrivialAccessors

        def validates(*args)
          @validates = *args
        end

        # rubocop:disable TrivialAccessors
        def validates_reader
          @validates
        end
        # rubocop:enable TrivialAccessors
      end
    end

    describe Parameters do
      subject { ParametersSpec::Dummy.new }

      describe '#use' do
        before do
          allow_message_expectations_on_nil
          allow(subject.api).to receive(:namespace_stackable).with(:named_params)
        end
        let(:options) { { option: 'value' } }
        let(:named_params) { { params_group: proc {} } }

        it 'calls processes associated with named params' do
          allow(Grape::DSL::Configuration).to receive(:stacked_hash_to_hash).and_return(named_params)
          expect(subject).to receive(:instance_exec).with(options).and_yield
          subject.use :params_group, options
        end

        it 'raises error when non-existent named param is called' do
          allow(Grape::DSL::Configuration).to receive(:stacked_hash_to_hash).and_return({})
          expect { subject.use :params_group }.to raise_error('Params :params_group not found!')
        end
      end

      describe '#use_scope' do
        it 'is alias to #use' do
          expect(subject.method(:use_scope)).to eq subject.method(:use)
        end
      end

      describe '#includes' do
        it 'is alias to #use' do
          expect(subject.method(:includes)).to eq subject.method(:use)
        end
      end

      describe '#requires' do
        it 'adds a required parameter' do
          subject.requires :id, type: Integer, desc: 'Identity.'

          expect(subject.validate_attributes_reader).to eq([[:id], { type: Integer, desc: 'Identity.', presence: true }])
          expect(subject.push_declared_params_reader).to eq([[:id]])
        end
      end

      describe '#optional' do
        it 'adds an optional parameter' do
          subject.optional :id, type: Integer, desc: 'Identity.'

          expect(subject.validate_attributes_reader).to eq([[:id], { type: Integer, desc: 'Identity.' }])
          expect(subject.push_declared_params_reader).to eq([[:id]])
        end
      end

      describe '#mutually_exclusive' do
        it 'adds an mutally exclusive parameter validation' do
          subject.mutually_exclusive :media, :audio

          expect(subject.validates_reader).to eq([[:media, :audio], { mutual_exclusion: true }])
        end
      end

      describe '#exactly_one_of' do
        it 'adds an exactly of one parameter validation' do
          subject.exactly_one_of :media, :audio

          expect(subject.validates_reader).to eq([[:media, :audio], { exactly_one_of: true }])
        end
      end

      describe '#at_least_one_of' do
        it 'adds an at least one of parameter validation' do
          subject.at_least_one_of :media, :audio

          expect(subject.validates_reader).to eq([[:media, :audio], { at_least_one_of: true }])
        end
      end

      describe '#all_or_none_of' do
        it 'adds an all or none of parameter validation' do
          subject.all_or_none_of :media, :audio

          expect(subject.validates_reader).to eq([[:media, :audio], { all_or_none_of: true }])
        end
      end

      describe '#group' do
        it 'is alias to #requires' do
          expect(subject.method(:group)).to eq subject.method(:requires)
        end
      end

      describe '#params' do
        it 'inherits params from parent' do
          parent_params = { foo: 'bar' }
          subject.parent = Object.new
          allow(subject.parent).to receive(:params).and_return(parent_params)
          expect(subject.params({})).to eq parent_params
        end

        describe 'when params argument is an array of hashes' do
          it 'returns values of each hash for @element key' do
            subject.element = :foo
            expect(subject.params([{ foo: 'bar' }, { foo: 'baz' }])).to eq(%w(bar baz))
          end
        end

        describe 'when params argument is a hash' do
          it 'returns value for @element key' do
            subject.element = :foo
            expect(subject.params(foo: 'bar')).to eq('bar')
          end
        end

        describe 'when params argument is not a array or a hash' do
          it 'returns empty hash' do
            subject.element = Object.new
            expect(subject.params(Object.new)).to eq({})
          end
        end
      end
    end
  end
end
