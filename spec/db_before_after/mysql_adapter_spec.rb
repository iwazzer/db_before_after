# frozen_string_literal: true

require 'spec_helper'
require 'time'

RSpec.describe DbBeforeAfter::MySQLAdapter do
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

  let(:adapter) { described_class.new(db_info) }
  let(:mock_connection) { instance_double(Mysql2::Client) }

  describe '#connect' do
    it 'creates a new MySQL connection' do
      expect(Mysql2::Client).to receive(:new).with(
        host: '127.0.0.1',
        username: 'test_user',
        password: 'test_pass',
        database: 'test_db',
        port: 3306,
        encoding: 'utf8'
      ).and_return(mock_connection)

      result = adapter.connect
      expect(result).to eq(mock_connection)
    end

    it 'returns the same connection on subsequent calls' do
      allow(Mysql2::Client).to receive(:new).and_return(mock_connection)
      
      first_call = adapter.connect
      second_call = adapter.connect
      
      expect(first_call).to eq(second_call)
    end
  end

  describe '#disconnect' do
    before do
      allow(Mysql2::Client).to receive(:new).and_return(mock_connection)
      adapter.connect
    end

    it 'closes the connection' do
      expect(mock_connection).to receive(:close)
      
      adapter.disconnect
    end

    it 'clears the connection instance variable' do
      allow(mock_connection).to receive(:close)
      
      adapter.disconnect
      
      expect(adapter.instance_variable_get(:@connection)).to be_nil
    end
  end

  describe '#list_tables' do
    let(:mock_stmt) { instance_double(Mysql2::Statement) }
    let(:mock_result) { [{ 'TABLE_NAME' => 'users' }, { 'TABLE_NAME' => 'posts' }] }

    before do
      allow(adapter).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:prepare).with(described_class::SELECT_TABLES).and_return(mock_stmt)
      allow(mock_stmt).to receive(:execute).with('test_db').and_return(mock_result)
    end

    it 'returns list of table names' do
      result = adapter.list_tables
      
      expect(result).to eq(['users', 'posts'])
    end
  end

  describe '#get_table_columns' do
    let(:mock_stmt) { instance_double(Mysql2::Statement) }
    let(:mock_result) do
      [
        { 'COLUMN_NAME' => 'id', 'DATA_TYPE' => 'int' },
        { 'COLUMN_NAME' => 'name', 'DATA_TYPE' => 'varchar' }
      ]
    end

    before do
      allow(adapter).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:prepare).with(described_class::SELECT_COLUMNS).and_return(mock_stmt)
      allow(mock_stmt).to receive(:execute).with('test_db', 'users').and_return(mock_result)
    end

    it 'returns column information for the table' do
      result = adapter.get_table_columns('users')
      
      expect(result).to eq(mock_result)
    end
  end

  describe '#get_table_data' do
    let(:mock_result) do
      [
        { 'id' => 1, 'name' => 'John' },
        { 'id' => 2, 'name' => 'Jane' }
      ]
    end

    before do
      allow(adapter).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:query).with('SELECT * FROM users').and_return(mock_result)
    end

    it 'returns table data' do
      result = adapter.get_table_data('users')
      
      expect(result).to eq(mock_result)
    end
  end

  describe '#format_value' do
    context 'when value is nil' do
      it 'returns nil' do
        result = adapter.format_value(nil, 'varchar')
        
        expect(result).to be_nil
      end
    end

    context 'when data_type is blob' do
      it 'returns MD5 hash' do
        result = adapter.format_value('binary_data', 'blob')
        
        expect(result).to match(/^MD5 Digest value: [a-f0-9]{32}$/)
      end
    end

    context 'when data_type is datetime' do
      it 'formats datetime correctly' do
        time = Time.parse('2023-01-01 10:00:00')
        result = adapter.format_value(time, 'datetime')
        
        expect(result).to eq('2023-01-01 10:00:00 JST')
      end
    end

    context 'when data_type is other' do
      it 'converts to UTF-8 string' do
        result = adapter.format_value('test string', 'varchar')
        
        expect(result).to eq('test string')
      end

      it 'handles frozen strings' do
        frozen_str = 'frozen'.freeze
        result = adapter.format_value(frozen_str, 'varchar')
        
        expect(result).to eq('frozen')
      end
    end
  end

  describe '#read_database' do
    let(:mock_tables_stmt) { instance_double(Mysql2::Statement) }
    let(:mock_columns_stmt) { instance_double(Mysql2::Statement) }
    let(:mock_tables) { ['users'] }
    let(:mock_columns) do
      [
        { 'COLUMN_NAME' => 'id', 'DATA_TYPE' => 'int' },
        { 'COLUMN_NAME' => 'name', 'DATA_TYPE' => 'varchar' }
      ]
    end
    let(:mock_data) do
      [
        { 'id' => 1, 'name' => 'John' },
        { 'id' => 2, 'name' => 'Jane' }
      ]
    end

    before do
      allow(adapter).to receive(:list_tables).and_return(mock_tables)
      allow(adapter).to receive(:get_table_columns).with('users').and_return(mock_columns)
      allow(adapter).to receive(:get_table_data).with('users').and_return(mock_data)
      allow(adapter).to receive(:format_value).and_return('formatted_value')
    end

    it 'returns database structure with formatted values' do
      result = adapter.read_database
      
      expect(result).to be_a(Hash)
      expect(result.keys).to contain_exactly('users')
      expect(result['users']).to be_an(Array)
      expect(result['users'].length).to eq(2)
    end

    it 'formats values using format_value method' do
      expect(adapter).to receive(:format_value).with(1, 'int').and_return('1')
      expect(adapter).to receive(:format_value).with('John', 'varchar').and_return('John')
      expect(adapter).to receive(:format_value).with(2, 'int').and_return('2')
      expect(adapter).to receive(:format_value).with('Jane', 'varchar').and_return('Jane')
      
      adapter.read_database
    end
  end
end