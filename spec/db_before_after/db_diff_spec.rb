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
  let(:mock_output_adapter) { instance_double(DbBeforeAfter::HtmlOutputAdapter) }
  let(:db_diff) { described_class.new(tempfile, db_info) }

  after { tempfile.close }

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(db_diff.instance_variable_get(:@file)).to eq(tempfile)
      expect(db_diff.instance_variable_get(:@db_info)).to eq(db_info)
      expect(db_diff.instance_variable_get(:@adapter)).to be_a(DbBeforeAfter::MySQLAdapter)
      expect(db_diff.instance_variable_get(:@output_adapter)).to be_a(DbBeforeAfter::HtmlOutputAdapter)
      expect(db_diff.instance_variable_get(:@no_diff)).to be true
    end

    it 'allows custom adapter classes' do
      custom_adapter_class = Class.new(DbBeforeAfter::DatabaseAdapter)
      custom_output_adapter_class = Class.new(DbBeforeAfter::OutputAdapter)
      allow(custom_adapter_class).to receive(:new).and_return(mock_adapter)
      allow(custom_output_adapter_class).to receive(:new).and_return(mock_output_adapter)
      
      db_diff = described_class.new(tempfile, db_info, custom_adapter_class, custom_output_adapter_class)
      
      expect(db_diff.instance_variable_get(:@adapter)).to eq(mock_adapter)
      expect(db_diff.instance_variable_get(:@output_adapter)).to eq(mock_output_adapter)
    end
  end

  describe '#execute' do
    let(:mock_before_db) { { 'users' => [{ 'id' => 1, 'name' => 'John' }] } }
    let(:mock_after_db) { { 'users' => [{ 'id' => 1, 'name' => 'John Updated' }] } }
    let(:mock_diff) { instance_double(Diffy::SplitDiff, left: '<div>left</div>', right: '<div>right</div>') }

    before do
      allow(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).and_return(mock_before_db, mock_after_db)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:start_output)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:end_output)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_title)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_diff_section)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_no_diff_message)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:generate_diff).and_return(mock_diff)
      allow(STDIN).to receive(:getc).and_return("\n")
      allow(STDOUT).to receive(:puts)
    end

    it 'reads database twice and processes changes' do
      expect(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).twice
      
      db_diff.execute
    end

    it 'uses output adapter to generate output' do
      expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:start_output)
      expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:end_output)
      
      db_diff.execute
    end

    it 'detects changes and sets no_diff flag appropriately' do
      db_diff.execute
      
      expect(db_diff.instance_variable_get(:@no_diff)).to be false
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