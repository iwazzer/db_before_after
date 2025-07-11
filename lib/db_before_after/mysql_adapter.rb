# frozen_string_literal: true

require 'mysql2'
require 'digest'
require_relative 'database_adapter'

module DbBeforeAfter
  class MySQLAdapter < DatabaseAdapter
    SELECT_TABLES = 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = ?'.freeze
    SELECT_COLUMNS = 'SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE table_schema = ? AND table_name = ?'.freeze

    def connect
      @connection ||= Mysql2::Client.new(
        host: connection_params[:host],
        username: connection_params[:username],
        password: connection_params[:password],
        database: connection_params[:database],
        port: connection_params[:port],
        encoding: connection_params[:encoding]
      )
    end

    def disconnect
      @connection&.close
      @connection = nil
    end

    def read_database
      db_data = []
      tables = list_tables
      
      tables.each do |table_name|
        columns = get_table_columns(table_name)
        data = get_table_data(table_name)
        
        formatted_data = data.map do |row|
          row.map do |column_name, value|
            column_type = columns.find { |col| col['COLUMN_NAME'] == column_name }&.dig('DATA_TYPE')
            formatted_value = format_value(value, column_type)
            [column_name, formatted_value]
          end.to_h
        end
        
        db_data << [table_name, formatted_data]
      end
      
      db_data.to_h
    end

    def list_tables
      @tables_stmt ||= connection.prepare(SELECT_TABLES)
      tables = @tables_stmt.execute(connection_params[:database])
      tables.map { |table| table['TABLE_NAME'] }
    end

    def get_table_columns(table_name)
      @columns_stmt ||= connection.prepare(SELECT_COLUMNS)
      @columns_stmt.execute(connection_params[:database], table_name).to_a
    end

    def get_table_data(table_name)
      connection.query("SELECT * FROM #{table_name}").to_a
    end

    def format_value(value, data_type)
      return nil if value.nil?
      
      case data_type
      when /blob\Z/
        "MD5 Digest value: #{Digest::MD5.hexdigest(value)}"
      when 'datetime'
        value.strftime('%Y-%m-%d %H:%M:%S %Z')
      else
        value.frozen? ? value.to_s : value.to_s.force_encoding(Encoding::UTF_8)
      end
    end

    private

    def connection
      @connection || connect
    end
  end
end