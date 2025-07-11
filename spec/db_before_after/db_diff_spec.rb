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
  let(:db_diff) { described_class.new(tempfile, db_info) }

  after { tempfile.close }

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(db_diff.instance_variable_get(:@file)).to eq(tempfile)
      expect(db_diff.instance_variable_get(:@db_info)).to eq(db_info)
      expect(db_diff.instance_variable_get(:@no_diff)).to be true
    end
  end

  describe '#db_conn' do
    let(:mock_client) { instance_double(Mysql2::Client) }

    before do
      allow(Mysql2::Client).to receive(:new).and_return(mock_client)
    end

    it 'creates a new MySQL client with correct parameters' do
      expect(Mysql2::Client).to receive(:new).with(
        host: '127.0.0.1',
        username: 'test_user',
        password: 'test_pass',
        database: 'test_db',
        port: 3306,
        encoding: 'utf8'
      )

      db_diff.db_conn
    end

    it 'returns the same client instance on subsequent calls' do
      first_call = db_diff.db_conn
      second_call = db_diff.db_conn
      
      expect(first_call).to eq(second_call)
    end

    context 'when environment variables are set' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('DB_HOST').and_return('env_host')
        allow(ENV).to receive(:[]).with('DB_USERNAME').and_return('env_user')
        allow(ENV).to receive(:[]).with('DB_PASSWORD').and_return('env_pass')
        allow(ENV).to receive(:[]).with('DB_DATABASE').and_return('env_db')
        allow(ENV).to receive(:[]).with('DB_PORT').and_return('3307')
        allow(ENV).to receive(:[]).with('DB_ENCODING').and_return('utf8mb4')
      end

      it 'uses environment variables over db_info' do
        expect(Mysql2::Client).to receive(:new).with(
          host: 'env_host',
          username: 'env_user',
          password: 'env_pass',
          database: 'env_db',
          port: '3307',
          encoding: 'utf8mb4'
        )

        db_diff.db_conn
      end
    end
  end

  describe '#read_db' do
    let(:mock_client) { instance_double(Mysql2::Client) }
    let(:mock_tables_stmt) { instance_double(Mysql2::Statement) }
    let(:mock_columns_stmt) { instance_double(Mysql2::Statement) }
    let(:mock_tables_result) { [{ 'TABLE_NAME' => 'users' }, { 'TABLE_NAME' => 'posts' }] }
    let(:mock_columns_result) do
      [
        { 'COLUMN_NAME' => 'id', 'DATA_TYPE' => 'int' },
        { 'COLUMN_NAME' => 'name', 'DATA_TYPE' => 'varchar' },
        { 'COLUMN_NAME' => 'created_at', 'DATA_TYPE' => 'datetime' }
      ]
    end
    let(:mock_records_result) do
      [
        { 'id' => 1, 'name' => 'John', 'created_at' => Time.parse('2023-01-01 10:00:00') },
        { 'id' => 2, 'name' => 'Jane', 'created_at' => Time.parse('2023-01-02 11:00:00') }
      ]
    end

    before do
      allow(db_diff).to receive(:db_conn).and_return(mock_client)
      allow(mock_client).to receive(:prepare).with(DbBeforeAfter::DbDiff::SELECT_TABLES).and_return(mock_tables_stmt)
      allow(mock_client).to receive(:prepare).with(DbBeforeAfter::DbDiff::SELECT_COLUMNS).and_return(mock_columns_stmt)
      allow(mock_tables_stmt).to receive(:execute).and_return(mock_tables_result)
      allow(mock_columns_stmt).to receive(:execute).and_return(mock_columns_result)
      allow(mock_client).to receive(:query).and_return(mock_records_result)
    end

    it 'returns database structure as hash' do
      result = db_diff.read_db

      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly('users', 'posts')
    end

    it 'formats datetime fields correctly' do
      result = db_diff.read_db
      user_record = result['users'].first

      expect(user_record['created_at']).to eq('2023-01-01 10:00:00 JST')
    end

    it 'handles blob fields with MD5 digest' do
      blob_columns = [{ 'COLUMN_NAME' => 'data', 'DATA_TYPE' => 'blob' }]
      blob_records = [{ 'data' => 'binary_data' }]

      allow(mock_columns_stmt).to receive(:execute).and_return(blob_columns)
      allow(mock_client).to receive(:query).and_return(blob_records)

      result = db_diff.read_db
      record = result['users'].first

      expect(record['data']).to match(/^MD5 Digest value: [a-f0-9]{32}$/)
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