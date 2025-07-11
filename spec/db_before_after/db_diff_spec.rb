# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'json'
require 'time'

RSpec.describe DbBeforeAfter::DbDiff do
  let(:db_info) do
    {
      host: '127.0.0.1',
      port: 3306,
      username: 'test_user',
      password: 'test_pass',
      database: 'test_db',
      encoding: 'utf8'
    }
  end

  let(:tempfile) { Tempfile.new('test_output.html') }
  let(:mock_adapter) { instance_double(DbBeforeAfter::MySQLAdapter) }
  let(:db_diff) { described_class.new(tempfile, db_info) }

  after { tempfile.close }

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(db_diff.instance_variable_get(:@file)).to eq(tempfile)
      expect(db_diff.instance_variable_get(:@db_info)).to eq(db_info)
      expect(db_diff.instance_variable_get(:@adapter)).to be_a(DbBeforeAfter::MySQLAdapter)
      expect(db_diff.instance_variable_get(:@no_diff)).to be true
    end

    it 'allows custom adapter class' do
      custom_adapter_class = Class.new(DbBeforeAfter::DatabaseAdapter)
      allow(custom_adapter_class).to receive(:new).and_return(mock_adapter)
      
      db_diff = described_class.new(tempfile, db_info, custom_adapter_class)
      
      expect(db_diff.instance_variable_get(:@adapter)).to eq(mock_adapter)
    end
  end

  describe '#execute' do
    let(:mock_before_db) { { 'users' => [{ 'id' => 1, 'name' => 'John' }] } }
    let(:mock_after_db) { { 'users' => [{ 'id' => 1, 'name' => 'John Updated' }] } }

    before do
      allow(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).and_return(mock_before_db, mock_after_db)
      allow(STDIN).to receive(:getc).and_return("\n")
      allow(STDOUT).to receive(:puts)
    end

    it 'reads database twice and processes changes' do
      expect(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).twice
      
      db_diff.execute
    end

    it 'detects changes and sets no_diff flag appropriately' do
      db_diff.execute
      
      expect(db_diff.instance_variable_get(:@no_diff)).to be false
    end
  end

  describe '#replace_code' do
    it 'replaces spaces with &nbsp; and newlines with <br/>' do
      input = "Hello World\nSecond Line"
      expected = "Hello&nbsp;World<br/>Second&nbsp;Line"
      
      result = db_diff.replace_code(input)
      expect(result).to eq(expected)
    end

    it 'returns nil when input is nil' do
      result = db_diff.replace_code(nil)
      expect(result).to be_nil
    end
  end

  describe '#output_title' do
    it 'writes HTML title to file' do
      db_diff.output_title('Test Title', tempfile)
      tempfile.rewind
      
      expect(tempfile.read).to include('<h2>Test Title</h2>')
    end
  end

  describe '#output_left' do
    it 'writes left diff container to file' do
      db_diff.output_left('diff content', tempfile)
      tempfile.rewind
      
      content = tempfile.read
      expect(content).to include('<div class="diff-part"><div class="diff-left">')
      expect(content).to include('diff content')
    end
  end

  describe '#output_right' do
    it 'writes right diff container to file' do
      db_diff.output_right('diff content', tempfile)
      tempfile.rewind
      
      content = tempfile.read
      expect(content).to include('</div><div class="diff-right">')
      expect(content).to include('diff content')
      expect(content).to include('</div></div>')
    end
  end

  describe '#write_html' do
    it 'generates complete HTML structure' do
      db_diff.write_html(tempfile) do |title, left, right|
        title.call('Test Section')
        left.call('left content')
        right.call('right content')
      end
      
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<html>')
      expect(content).to include('<head>')
      expect(content).to include('<meta charset="UTF-8">')
      expect(content).to include('<style>')
      expect(content).to include('</style>')
      expect(content).to include('</head>')
      expect(content).to include('<body>')
      expect(content).to include('<h2>Test Section</h2>')
      expect(content).to include('left content')
      expect(content).to include('right content')
      expect(content).to include('</body>')
      expect(content).to include('</html>')
    end

    it 'includes Diffy CSS in the output' do
      db_diff.write_html(tempfile) { |title, left, right| }
      
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('.diff-part { width: 100%; overflow: hidden; }')
      expect(content).to include('.diff-left { width: 49%; float: left; }')
      expect(content).to include('.diff-right { margin-left: 50%; }')
    end
  end

  describe '.execute' do
    let(:mock_file) { instance_double(File) }
    let(:mock_db_diff) { instance_double(DbBeforeAfter::DbDiff) }
    let(:mock_ulid) { 'test_ulid' }

    before do
      allow(ULID).to receive(:generate).and_return(mock_ulid)
      allow(File).to receive(:open).and_return(mock_file)
      allow(mock_file).to receive(:close)
      allow(DbBeforeAfter::DbDiff).to receive(:new).and_return(mock_db_diff)
      allow(mock_db_diff).to receive(:execute)
      allow(Clipboard).to receive(:copy)
      allow(STDOUT).to receive(:puts)
    end

    it 'creates output file with ULID and suffix' do
      expected_path = Pathname.new("/tmp/#{mock_ulid}_test_suffix")
      
      expect(File).to receive(:open).with(expected_path, 'w')
      
      described_class.execute('test_suffix', db_info)
    end

    it 'copies open command to clipboard' do
      expected_path = Pathname.new("/tmp/#{mock_ulid}_test_suffix")
      
      expect(Clipboard).to receive(:copy).with("open #{expected_path}")
      
      described_class.execute('test_suffix', db_info)
    end

    it 'outputs file path to stdout' do
      expected_path = Pathname.new("/tmp/#{mock_ulid}_test_suffix")
      
      expect(STDOUT).to receive(:puts).with("output: #{expected_path} (Copied to clipboard)")
      
      described_class.execute('test_suffix', db_info)
    end

    it 'ensures file is closed even on error' do
      allow(mock_db_diff).to receive(:execute).and_raise(StandardError, 'Test error')
      
      expect(mock_file).to receive(:close)
      expect(STDERR).to receive(:puts).with('Test error')
      expect(STDERR).to receive(:puts).with(anything)
      
      described_class.execute('test_suffix', db_info)
    end

    context 'when Rails is defined' do
      before do
        rails_double = double('Rails')
        allow(rails_double).to receive(:root).and_return(Pathname.new('/rails/root'))
        stub_const('Rails', rails_double)
      end

      it 'uses Rails.root for output path' do
        expected_path = Pathname.new("/rails/root/#{mock_ulid}_test_suffix")
        
        expect(File).to receive(:open).with(expected_path, 'w')
        
        described_class.execute('test_suffix', db_info)
      end
    end
  end
end