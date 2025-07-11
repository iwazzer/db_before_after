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
  let(:mock_output_adapter) { instance_double(DbBeforeAfter::HtmlOutputAdapter) }
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
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:start_output)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:end_output)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_title)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_diff_section)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_no_diff_message)
      allow(db_diff.instance_variable_get(:@output_adapter)).to receive(:generate_diff).and_return(
        instance_double(Diffy::SplitDiff, left: '<div>left</div>', right: '<div>right</div>')
      )
      allow(STDIN).to receive(:getc).and_return("\n")
      allow(STDOUT).to receive(:puts)
    end

    context 'when there are database changes' do
      it 'uses output adapter to generate output' do
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:start_output)
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_title).with('users')
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_diff_section)
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:end_output)
        
        db_diff.execute
      end

      it 'detects changes and calls appropriate output methods' do
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:generate_diff).at_least(:once)
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_title).with('users')
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_diff_section).at_least(:once)
        
        db_diff.execute
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

      it 'calls write_no_diff_message when no changes' do
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_no_diff_message)
        
        db_diff.execute
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

      it 'processes all tables with changes' do
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_title).with('posts')
        
        db_diff.execute
      end

      it 'detects changes in multiple tables' do
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:generate_diff).at_least(:once)
        expect(db_diff.instance_variable_get(:@output_adapter)).to receive(:write_diff_section).at_least(:once)
        
        db_diff.execute
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