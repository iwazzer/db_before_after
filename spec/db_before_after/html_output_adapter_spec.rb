# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe DbBeforeAfter::HtmlOutputAdapter do
  let(:tempfile) { Tempfile.new('test_output.html') }
  let(:adapter) { described_class.new(tempfile) }

  after { tempfile.close }

  describe '#initialize' do
    it 'sets file correctly' do
      expect(adapter.send(:file)).to eq(tempfile)
    end
  end

  describe '#start_output' do
    it 'writes HTML document start with CSS' do
      adapter.start_output
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<html>')
      expect(content).to include('<head>')
      expect(content).to include('<meta charset="UTF-8">')
      expect(content).to include('<style>')
      expect(content).to include('.diff-part { width: 100%; overflow: hidden; }')
      expect(content).to include('.diff-left { width: 49%; float: left; }')
      expect(content).to include('.diff-right { margin-left: 50%; }')
      expect(content).to include('</style>')
      expect(content).to include('</head>')
      expect(content).to include('<body>')
    end
  end

  describe '#end_output' do
    it 'writes HTML document end' do
      adapter.end_output
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('</body></html>')
    end
  end

  describe '#write_title' do
    it 'writes HTML title' do
      adapter.write_title('Test Title')
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<h2>Test Title</h2>')
    end
  end

  describe '#write_diff_section' do
    it 'writes diff section with left and right content' do
      adapter.write_diff_section('left content', 'right content')
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<div class="diff-part"><div class="diff-left">')
      expect(content).to include('left content')
      expect(content).to include('</div><div class="diff-right">')
      expect(content).to include('right content')
      expect(content).to include('</div></div>')
    end
  end

  describe '#write_no_diff_message' do
    it 'writes no diff message as title' do
      adapter.write_no_diff_message
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<h2>No diff</h2>')
    end
  end

  describe '#generate_diff' do
    it 'returns Diffy::SplitDiff object' do
      result = adapter.generate_diff('left content', 'right content')
      
      expect(result).to be_a(Diffy::SplitDiff)
    end

    it 'generates HTML format diff' do
      result = adapter.generate_diff('old text', 'new text')
      
      expect(result.left).to include('<div class="diff">')
      expect(result.right).to include('<div class="diff">')
    end
  end

  describe '#format_content' do
    it 'replaces spaces with &nbsp; and newlines with <br/>' do
      input = "Hello World\nSecond Line"
      expected = "Hello&nbsp;World<br/>Second&nbsp;Line"
      
      result = adapter.format_content(input)
      expect(result).to eq(expected)
    end

    it 'returns nil when input is nil' do
      result = adapter.format_content(nil)
      expect(result).to be_nil
    end
  end

  describe 'full HTML generation' do
    it 'generates complete HTML document' do
      adapter.start_output
      adapter.write_title('Test Table')
      adapter.write_diff_section('left diff', 'right diff')
      adapter.write_no_diff_message
      adapter.end_output
      
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<html>')
      expect(content).to include('<h2>Test Table</h2>')
      expect(content).to include('<div class="diff-part">')
      expect(content).to include('left diff')
      expect(content).to include('right diff')
      expect(content).to include('<h2>No diff</h2>')
      expect(content).to include('</body></html>')
    end
  end
end