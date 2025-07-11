#!/usr/bin/env ruby

require 'ulid'
require 'json'
require 'clipboard'
require 'pathname'
require_relative 'mysql_adapter'
require_relative 'html_output_adapter'

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

    def initialize(file, db_info, adapter_class = MySQLAdapter, output_adapter_class = HtmlOutputAdapter)
      @file = file
      @db_info = db_info
      @adapter = adapter_class.new(db_info)
      @output_adapter = output_adapter_class.new(file)
      @no_diff = true
    end

    def execute
      puts 'now reading db...'
      before_db = @adapter.read_database
      puts 'run usecase now. then press any key when done.'
      STDIN.getc
      puts 'now reading db...'
      after_db = @adapter.read_database

      @output_adapter.start_output
      
      before_db.each do |table_name, records|
        before = records.map { |r| [r['id'], JSON.pretty_generate(r)] }.to_h
        after = after_db[table_name].map { |r| [r['id'], JSON.pretty_generate(r)] }.to_h
        all_ids = (before.keys | after.keys).compact
        deleted_ids = before.keys - after.keys
        added_ids = after.keys - before.keys
        changed_ids = (before.keys & after.keys).select { |id| before[id] != after[id] }
        @no_diff = false if deleted_ids.any? || added_ids.any? || changed_ids.any?
        
        if deleted_ids.any? || added_ids.any? || changed_ids.any?
          @output_adapter.write_title(table_name)
          
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
            
            diff = @output_adapter.generate_diff(lj, rj)
            @output_adapter.write_diff_section(diff.left, diff.right)
          end
          
          @output_adapter.close_section if @output_adapter.respond_to?(:close_section)
        end
      end
      
      @output_adapter.write_no_diff_message if @no_diff
      @output_adapter.end_output
      puts 'done.'
    end

  end
end
