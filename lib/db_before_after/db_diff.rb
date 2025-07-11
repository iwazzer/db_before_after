#!/usr/bin/env ruby

require 'diffy'
require 'ulid'
require 'json'
require 'clipboard'
require_relative 'mysql_adapter'

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

    def initialize(file, db_info, adapter_class = MySQLAdapter)
      @file = file
      @db_info = db_info
      @adapter = adapter_class.new(db_info)
      @no_diff = true
    end

    def execute
      puts 'now reading db...'
      before_db = @adapter.read_database
      puts 'run usecase now. then press any key when done.'
      STDIN.getc
      puts 'now reading db...'
      after_db = @adapter.read_database

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
