# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe DbBeforeAfter::OutputAdapter do
  let(:tempfile) { Tempfile.new('test_output') }
  let(:adapter) { described_class.new(tempfile) }

  after { tempfile.close }

  describe '#initialize' do
    it 'sets file correctly' do
      expect(adapter.send(:file)).to eq(tempfile)
    end
  end

  describe '#start_output' do
    it 'raises NotImplementedError' do
      expect { adapter.start_output }.to raise_error(NotImplementedError, 'Subclass must implement start_output method')
    end
  end

  describe '#end_output' do
    it 'raises NotImplementedError' do
      expect { adapter.end_output }.to raise_error(NotImplementedError, 'Subclass must implement end_output method')
    end
  end

  describe '#write_title' do
    it 'raises NotImplementedError' do
      expect { adapter.write_title('Test Title') }.to raise_error(NotImplementedError, 'Subclass must implement write_title method')
    end
  end

  describe '#write_diff_section' do
    it 'raises NotImplementedError' do
      expect { adapter.write_diff_section('left', 'right') }.to raise_error(NotImplementedError, 'Subclass must implement write_diff_section method')
    end
  end

  describe '#write_no_diff_message' do
    it 'raises NotImplementedError' do
      expect { adapter.write_no_diff_message }.to raise_error(NotImplementedError, 'Subclass must implement write_no_diff_message method')
    end
  end

  describe '#generate_diff' do
    it 'raises NotImplementedError' do
      expect { adapter.generate_diff('left', 'right') }.to raise_error(NotImplementedError, 'Subclass must implement generate_diff method')
    end
  end

  describe '#format_content' do
    it 'raises NotImplementedError' do
      expect { adapter.format_content('content') }.to raise_error(NotImplementedError, 'Subclass must implement format_content method')
    end
  end
end