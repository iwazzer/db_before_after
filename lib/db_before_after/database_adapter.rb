# frozen_string_literal: true

module DbBeforeAfter
  class DatabaseAdapter
    def initialize(db_info)
      @db_info = db_info
    end

    def connect
      raise NotImplementedError, 'Subclass must implement connect method'
    end

    def disconnect
      raise NotImplementedError, 'Subclass must implement disconnect method'
    end

    def read_database
      raise NotImplementedError, 'Subclass must implement read_database method'
    end

    def list_tables
      raise NotImplementedError, 'Subclass must implement list_tables method'
    end

    def get_table_columns(table_name)
      raise NotImplementedError, 'Subclass must implement get_table_columns method'
    end

    def get_table_data(table_name)
      raise NotImplementedError, 'Subclass must implement get_table_data method'
    end

    def format_value(value, data_type)
      raise NotImplementedError, 'Subclass must implement format_value method'
    end

    protected

    def connection_params
      {
        host: ENV['DB_HOST'] || @db_info[:host],
        username: ENV['DB_USERNAME'] || @db_info[:username],
        password: ENV['DB_PASSWORD'] || @db_info[:password],
        database: ENV['DB_DATABASE'] || @db_info[:database],
        port: ENV['DB_PORT'] || @db_info[:port],
        encoding: ENV['DB_ENCODING'] || @db_info[:encoding]
      }
    end
  end
end