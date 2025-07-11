# frozen_string_literal: true

require 'diffy'
require_relative 'output_adapter'

module DbBeforeAfter
  class HtmlOutputAdapter < OutputAdapter
    def start_output
      file.puts '<html><head><meta charset="UTF-8"><style>'
      file.puts Diffy::CSS
      file.puts '.diff-part { width: 100%; overflow: hidden; }'
      file.puts '.diff-left { width: 49%; float: left; }'
      file.puts '.diff-right { margin-left: 50%; }'
      file.puts '</style></head>'
      file.puts '<body>'
    end

    def end_output
      file.puts '</body></html>'
    end

    def write_title(title)
      file.puts "<h2>#{title}</h2>"
    end

    def write_diff_section(left_content, right_content)
      file.puts '<div class="diff-part"><div class="diff-left">'
      file.puts left_content
      file.puts '</div><div class="diff-right">'
      file.puts right_content
      file.puts '</div></div>'
    end

    def write_no_diff_message
      write_title('No diff')
    end

    def generate_diff(left, right)
      Diffy::SplitDiff.new(left, right, format: :html)
    end

    def format_content(content)
      return if content.nil?

      content.gsub(' ', '&nbsp;').gsub("\n", '<br/>')
    end
  end
end