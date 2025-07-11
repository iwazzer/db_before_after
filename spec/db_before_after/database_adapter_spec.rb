# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DbBeforeAfter::DatabaseAdapter do
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

  describe '#initialize' do
    it 'sets db_info correctly' do
      expect(adapter.instance_variable_get(:@db_info)).to eq(db_info)
    end
  end

  describe '#connect' do
    it 'raises NotImplementedError' do
      expect { adapter.connect }.to raise_error(NotImplementedError, 'Subclass must implement connect method')
    end
  end

  describe '#disconnect' do
    it 'raises NotImplementedError' do
      expect { adapter.disconnect }.to raise_error(NotImplementedError, 'Subclass must implement disconnect method')
    end
  end

  describe '#read_database' do
    it 'raises NotImplementedError' do
      expect { adapter.read_database }.to raise_error(NotImplementedError, 'Subclass must implement read_database method')
    end
  end

  describe '#list_tables' do
    it 'raises NotImplementedError' do
      expect { adapter.list_tables }.to raise_error(NotImplementedError, 'Subclass must implement list_tables method')
    end
  end

  describe '#get_table_columns' do
    it 'raises NotImplementedError' do
      expect { adapter.get_table_columns('test_table') }.to raise_error(NotImplementedError, 'Subclass must implement get_table_columns method')
    end
  end

  describe '#get_table_data' do
    it 'raises NotImplementedError' do
      expect { adapter.get_table_data('test_table') }.to raise_error(NotImplementedError, 'Subclass must implement get_table_data method')
    end
  end

  describe '#format_value' do
    it 'raises NotImplementedError' do
      expect { adapter.format_value('value', 'varchar') }.to raise_error(NotImplementedError, 'Subclass must implement format_value method')
    end
  end

  describe '#connection_params' do
    it 'returns connection parameters from db_info' do
      params = adapter.send(:connection_params)
      
      expect(params[:host]).to eq('127.0.0.1')
      expect(params[:port]).to eq(3306)
      expect(params[:username]).to eq('test_user')
      expect(params[:password]).to eq('test_pass')
      expect(params[:database]).to eq('test_db')
      expect(params[:encoding]).to eq('utf8')
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
        params = adapter.send(:connection_params)
        
        expect(params[:host]).to eq('env_host')
        expect(params[:username]).to eq('env_user')
        expect(params[:password]).to eq('env_pass')
        expect(params[:database]).to eq('env_db')
        expect(params[:port]).to eq('3307')
        expect(params[:encoding]).to eq('utf8mb4')
      end
    end
  end
end