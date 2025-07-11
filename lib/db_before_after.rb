# frozen_string_literal: true

require_relative 'db_before_after/version'
require_relative 'db_before_after/database_adapter'
require_relative 'db_before_after/mysql_adapter'
require_relative 'db_before_after/output_adapter'
require_relative 'db_before_after/html_output_adapter'
require_relative 'db_before_after/db_diff'

module DbBeforeAfter
  class Error < StandardError; end
  # Your code goes here...
end
