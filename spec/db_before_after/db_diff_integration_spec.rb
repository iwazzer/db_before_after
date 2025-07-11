# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'json'

RSpec.describe DbBeforeAfter::DbDiff, 'Integration Tests' do
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

  describe '#execute' do
    let(:mock_client) { instance_double(Mysql2::Client) }
    let(:mock_tables_stmt) { instance_double(Mysql2::Statement) }
    let(:mock_columns_stmt) { instance_double(Mysql2::Statement) }
    
    let(:before_tables) { [{ 'TABLE_NAME' => 'users' }] }
    let(:before_columns) do
      [
        { 'COLUMN_NAME' => 'id', 'DATA_TYPE' => 'int' },
        { 'COLUMN_NAME' => 'name', 'DATA_TYPE' => 'varchar' },
        { 'COLUMN_NAME' => 'email', 'DATA_TYPE' => 'varchar' }
      ]
    end
    let(:before_records) do
      [
        { 'id' => 1, 'name' => 'John', 'email' => 'john@example.com' },
        { 'id' => 2, 'name' => 'Jane', 'email' => 'jane@example.com' }
      ]
    end

    let(:after_records) do
      [
        { 'id' => 1, 'name' => 'John Updated', 'email' => 'john@example.com' },
        { 'id' => 3, 'name' => 'Bob', 'email' => 'bob@example.com' }
      ]
    end

    before do
      allow(db_diff).to receive(:db_conn).and_return(mock_client)
      allow(mock_client).to receive(:prepare).with(DbBeforeAfter::DbDiff::SELECT_TABLES).and_return(mock_tables_stmt)
      allow(mock_client).to receive(:prepare).with(DbBeforeAfter::DbDiff::SELECT_COLUMNS).and_return(mock_columns_stmt)
      allow(mock_tables_stmt).to receive(:execute).and_return(before_tables)
      allow(mock_columns_stmt).to receive(:execute).and_return(before_columns)
      
      # Mock STDIN.getc to simulate user input
      allow(STDIN).to receive(:getc).and_return("\n")
      
      # Mock puts to avoid output during tests
      allow(STDOUT).to receive(:puts)
    end

    context 'when there are database changes' do
      before do
        # First call returns before_records, second call returns after_records
        allow(mock_client).to receive(:query).and_return(before_records, after_records)
      end

      it 'detects added records' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        # Should contain diff for added record (ID 3)
        expect(content).to include('Bob')
        expect(content).to include('bob@example.com')
      end

      it 'detects deleted records' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        # Should contain diff for deleted record (ID 2)
        expect(content).to include('Jane')
        expect(content).to include('jane@example.com')
      end

      it 'detects modified records' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        # Should contain diff for modified record (ID 1)
        expect(content).to include('John<strong> Updated</strong>')
        expect(content).to include('John')
      end

      it 'generates valid HTML structure' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        expect(content).to include('<html>')
        expect(content).to include('<head>')
        expect(content).to include('<meta charset="UTF-8">')
        expect(content).to include('<style>')
        expect(content).to include('</style>')
        expect(content).to include('</head>')
        expect(content).to include('<body>')
        expect(content).to include('<h2>users</h2>')
        expect(content).to include('<div class="diff-part">')
        expect(content).to include('<div class="diff-left">')
        expect(content).to include('<div class="diff-right">')
        expect(content).to include('</body>')
        expect(content).to include('</html>')
      end

      it 'includes table name as section title' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        expect(content).to include('<h2>users</h2>')
      end

      it 'sets no_diff flag to false when changes are detected' do
        db_diff.execute
        
        expect(db_diff.instance_variable_get(:@no_diff)).to be false
      end
    end

    context 'when there are no database changes' do
      before do
        # Both calls return the same records
        allow(mock_client).to receive(:query).and_return(before_records, before_records)
      end

      it 'shows "No diff" message' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        expect(content).to include('<h2>No diff</h2>')
      end

      it 'keeps no_diff flag as true' do
        db_diff.execute
        
        expect(db_diff.instance_variable_get(:@no_diff)).to be true
      end
    end

    context 'with multiple tables' do
      let(:multi_tables) { [{ 'TABLE_NAME' => 'users' }, { 'TABLE_NAME' => 'posts' }] }
      let(:posts_columns) do
        [
          { 'COLUMN_NAME' => 'id', 'DATA_TYPE' => 'int' },
          { 'COLUMN_NAME' => 'title', 'DATA_TYPE' => 'varchar' },
          { 'COLUMN_NAME' => 'content', 'DATA_TYPE' => 'text' }
        ]
      end
      let(:posts_before) { [{ 'id' => 1, 'title' => 'Post 1', 'content' => 'Content 1' }] }
      let(:posts_after) { [{ 'id' => 1, 'title' => 'Updated Post 1', 'content' => 'Content 1' }] }

      before do
        allow(mock_tables_stmt).to receive(:execute).and_return(multi_tables)
        allow(mock_columns_stmt).to receive(:execute).and_return(before_columns, posts_columns, before_columns, posts_columns)
        allow(mock_client).to receive(:query).and_return(before_records, posts_before, before_records, posts_after)
      end

      it 'processes all tables' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        # Should contain posts table header since posts has changes
        expect(content).to include('<h2>posts</h2>')
      end

      it 'shows changes in each table' do
        db_diff.execute
        
        tempfile.rewind
        content = tempfile.read
        
        expect(content).to include('<strong>Updated </strong>Post 1')
        expect(content).to include('Post 1')
      end
    end
  end

  describe 'Error handling' do
    context 'when database connection fails' do
      before do
        allow(db_diff).to receive(:db_conn).and_raise(Mysql2::Error, 'Connection failed')
      end

      it 'raises the database error' do
        expect { db_diff.execute }.to raise_error(Mysql2::Error, 'Connection failed')
      end
    end

    context 'when query execution fails' do
      let(:mock_client) { instance_double(Mysql2::Client) }

      before do
        allow(db_diff).to receive(:db_conn).and_return(mock_client)
        allow(mock_client).to receive(:prepare).and_raise(Mysql2::Error, 'Query failed')
      end

      it 'raises the query error' do
        expect { db_diff.execute }.to raise_error(Mysql2::Error, 'Query failed')
      end
    end
  end
end