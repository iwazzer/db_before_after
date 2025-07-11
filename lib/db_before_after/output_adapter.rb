# frozen_string_literal: true

module DbBeforeAfter
  class OutputAdapter
    def initialize(file)
      @file = file
    end

    def start_output
      raise NotImplementedError, 'Subclass must implement start_output method'
    end

    def end_output
      raise NotImplementedError, 'Subclass must implement end_output method'
    end

    def write_title(title)
      raise NotImplementedError, 'Subclass must implement write_title method'
    end

    def write_diff_section(left_content, right_content)
      raise NotImplementedError, 'Subclass must implement write_diff_section method'
    end

    def write_no_diff_message
      raise NotImplementedError, 'Subclass must implement write_no_diff_message method'
    end

    def generate_diff(left, right)
      raise NotImplementedError, 'Subclass must implement generate_diff method'
    end

    def format_content(content)
      raise NotImplementedError, 'Subclass must implement format_content method'
    end

    protected

    attr_reader :file
  end
end