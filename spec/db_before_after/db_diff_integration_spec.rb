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
  let(:mock_adapter) { instance_double(DbBeforeAfter::MySQLAdapter) }
  let(:db_diff) { described_class.new(tempfile, db_info) }

  after { tempfile.close }

  describe '#execute' do
    let(:before_db) do
      {
        'users' => [
          { 'id' => 1, 'name' => 'John', 'email' => 'john@example.com' },
          { 'id' => 2, 'name' => 'Jane', 'email' => 'jane@example.com' }
        ]
      }
    end

    let(:after_db) do
      {
        'users' => [
          { 'id' => 1, 'name' => 'John Updated', 'email' => 'john@example.com' },
          { 'id' => 3, 'name' => 'Bob', 'email' => 'bob@example.com' }
        ]
      }
    end

    before do
      allow(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).and_return(before_db, after_db)
      allow(STDIN).to receive(:getc).and_return("\n")
      allow(STDOUT).to receive(:puts)
    end

    context 'when there are database changes' do

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
      let(:same_db) do
        {
          'users' => [
            { 'id' => 1, 'name' => 'John', 'email' => 'john@example.com' },
            { 'id' => 2, 'name' => 'Jane', 'email' => 'jane@example.com' }
          ]
        }
      end

      before do
        allow(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).and_return(same_db, same_db)
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
      let(:multi_before_db) do
        {
          'users' => [
            { 'id' => 1, 'name' => 'John', 'email' => 'john@example.com' }
          ],
          'posts' => [
            { 'id' => 1, 'title' => 'Post 1', 'content' => 'Content 1' }
          ]
        }
      end

      let(:multi_after_db) do
        {
          'users' => [
            { 'id' => 1, 'name' => 'John', 'email' => 'john@example.com' }
          ],
          'posts' => [
            { 'id' => 1, 'title' => 'Updated Post 1', 'content' => 'Content 1' }
          ]
        }
      end

      before do
        allow(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).and_return(multi_before_db, multi_after_db)
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
    context 'when database reading fails' do
      before do
        allow(db_diff.instance_variable_get(:@adapter)).to receive(:read_database).and_raise(StandardError, 'Database read failed')
      end

      it 'raises the database error' do
        expect { db_diff.execute }.to raise_error(StandardError, 'Database read failed')
      end
    end
  end
end