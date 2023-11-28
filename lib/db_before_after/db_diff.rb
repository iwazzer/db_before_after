#!/usr/bin/env ruby

require 'diffy'
require 'ulid'
require 'json'
require 'mysql2'
require 'clipboard'
require 'digest'

module DbBeforeAfter
  class DbDiff
    def self.execute(file_suffix, db_info)
      file = nil
      root_dir = Pathname.new('/tmp')
      root_dir = Rails.root if defined?(Rails)
      output_path = root_dir.join("#{ULID.generate}_#{file_suffix}")
      file = File.open(output_path, 'w')
      db_diff = DbDiff.new(file, db_info)
      db_diff.execute
      puts "output: #{output_path} (Copied to clipboard)"
      Clipboard.copy "open #{output_path}"
    rescue StandardError => e
      STDERR.puts e.message
      STDERR.puts e.backtrace&.join("\n")
    ensure
      file.close if file
    end

    def initialize(file, db_info)
      @file = file
      @db_info = db_info
      @no_diff = true
    end

    def execute
      puts 'now reading db...'
      before_db = read_db
      puts 'run usecase now. then press any key when done.'
      STDIN.getc
      puts 'now reading db...'
      after_db = read_db

      write_html(@file) do |title, left, right|
        before_db.each do |table_name, records|
          before = records.map { |r| [r['id'], JSON.pretty_generate(r)] }.to_h
          after = after_db[table_name].map { |r| [r['id'], JSON.pretty_generate(r)] }.to_h
          all_ids = (before.keys | after.keys).compact
          deleted_ids = before.keys - after.keys
          added_ids = after.keys - before.keys
          changed_ids = (before.keys & after.keys).select { |id| before[id] != after[id] }
          @no_diff = false if deleted_ids.any? || added_ids.any? || changed_ids.any?
          all_ids.each do |id|
            lj, rj = if deleted_ids.include?(id)
                       [before[id], '']
                     elsif added_ids.include?(id)
                       ['', after[id]]
                     elsif changed_ids.include?(id)
                       [before[id], after[id]]
                     else
                       next
                     end
            diff = Diffy::SplitDiff.new(lj, rj, format: :html)
            title.call(table_name)
            left.call(diff.left)
            right.call(diff.right)
          end
        end
        title.call('No diff') if @no_diff
        puts 'done.'
      end
    end

    def db_conn
      @db_conn ||= Mysql2::Client.new(
        host: ENV['DB_HOST'] || @db_info[:host],
        username: ENV['DB_USERNAME'] || @db_info[:username],
        password: ENV['DB_PASSWORD'] || @db_info[:password],
        database: ENV['DB_DATABASE'] || @db_info[:database],
        port: ENV['DB_PORT'] || @db_info[:port],
        encoding: ENV['DB_ENCODING'] || @db_info[:encoding]
      )
    end

    SELECT_TABLES = 'SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = ?'.freeze
    SELECT_COLUMNS = 'SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE table_schema = ? AND table_name = ?'.freeze

    def read_db
      db_data = []
      @tables_stmt ||= db_conn.prepare(SELECT_TABLES)
      tables = @tables_stmt.execute(@db_info[:database])
      @columns_stmt ||= db_conn.prepare(SELECT_COLUMNS)
      tables.each do |table|
        table_name = table['TABLE_NAME']

        columns = @columns_stmt.execute(@db_info[:database], table_name)

        records = db_conn.query("SELECT * FROM #{table_name}")
        rows = records.to_a.map do |row|
          row.map do |k, v|
            type_info = columns.map { |h| [h['COLUMN_NAME'], h['DATA_TYPE']]  }.to_h
            value = case type_info[k]
                    when /blob\Z/
                      "MD5 Digest value: #{Digest::MD5.hexdigest(v)}"
                    when 'datetime'
                      v.strftime('%Y-%m-%d %H:%M:%S %Z') unless v.nil?
                    else
                      v.frozen? ? v.to_s : v.to_s.force_encoding(Encoding::UTF_8)
                    end
            [k, value]
          end.to_h
        end
        db_data << [table_name,  rows]
      end
      db_data.to_h
    end

    def replace_code(str)
      return if str.nil?

      str.gsub(' ', '&nbsp;').gsub("\n", '<br/>')
    end

    def output_title(title, file)
      file.puts "<h2>#{title}</h2>"
    end

    def output_left(left, file)
      file.puts '<div class="diff-part"><div class="diff-left">'
      file.puts left
    end

    def output_right(right, file)
      file.puts '</div><div class="diff-right">'
      file.puts right
      file.puts '</div></div>'
    end

    def write_html(file)
      file.puts '<html><head><meta charset="UTF-8"><style>'
      file.puts Diffy::CSS
      file.puts '.diff-part { width: 100%; overflow: hidden; }'
      file.puts '.diff-left { width: 49%; float: left; }'
      file.puts '.diff-right { margin-left: 50%; }'
      file.puts '</style></head>'
      title = ->(table) { self.output_title(table, file) }
      left = ->(diff) { self.output_left(diff, file) }
      right = ->(diff) { self.output_right(diff, file) }
      file.puts '<body>'
      yield(title, left, right)
      file.puts '</body></html>'
    end
  end
end
