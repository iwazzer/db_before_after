# frozen_string_literal: true

require 'diffy'
require_relative 'output_adapter'

module DbBeforeAfter
  class HtmlOutputAdapter < OutputAdapter
    def start_output
      file.puts <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Database Diff Report</title>
          <style>
            #{modern_css}
            #{diffy_css}
          </style>
        </head>
        <body>
          <div class="container">
            <header class="header">
              <h1>Database Diff Report</h1>
              <p class="subtitle">Generated at #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>
            </header>
            <main class="main-content">
      HTML
    end

    def end_output
      file.puts <<~HTML
            </main>
            <footer class="footer">
              <p>Generated by <a href="https://github.com/iwazzer/db_before_after" target="_blank">db_before_after</a></p>
            </footer>
          </div>
        </body>
        </html>
      HTML
    end

    def write_title(title)
      file.puts <<~HTML
        <section class="table-section">
          <h2 class="table-title">#{title}</h2>
          <div class="diff-container">
      HTML
    end

    def write_diff_section(left_content, right_content)
      file.puts <<~HTML
        <div class="diff-part">
          <div class="diff-side diff-left">
            <h3 class="diff-header">Before</h3>
            <div class="diff-content">#{left_content}</div>
          </div>
          <div class="diff-side diff-right">
            <h3 class="diff-header">After</h3>
            <div class="diff-content">#{right_content}</div>
          </div>
        </div>
      HTML
    end

    def write_no_diff_message
      file.puts <<~HTML
        <div class="no-diff-message">
          <div class="no-diff-icon">✅</div>
          <h2>No Changes Detected</h2>
          <p>The database state remained unchanged during the operation.</p>
        </div>
      HTML
    end

    def close_section
      file.puts <<~HTML
          </div>
        </section>
      HTML
    end

    def generate_diff(left, right)
      Diffy::SplitDiff.new(left, right, format: :html)
    end

    def format_content(content)
      return if content.nil?

      content.gsub(' ', '&nbsp;').gsub("\n", '<br/>')
    end

    private

    def modern_css
      <<~CSS
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
          line-height: 1.6;
          color: #333;
          background-color: #f8f9fa;
        }

        .container {
          max-width: 1200px;
          margin: 0 auto;
          padding: 20px;
        }

        .header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 2rem;
          border-radius: 12px;
          margin-bottom: 2rem;
          box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }

        .header h1 {
          font-size: 2.5rem;
          font-weight: 700;
          margin-bottom: 0.5rem;
        }

        .subtitle {
          font-size: 1.1rem;
          opacity: 0.9;
        }

        .main-content {
          min-height: 400px;
        }

        .table-section {
          background: white;
          border-radius: 12px;
          padding: 2rem;
          margin-bottom: 2rem;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
          border: 1px solid #e9ecef;
        }

        .table-title {
          font-size: 1.8rem;
          font-weight: 600;
          color: #2c3e50;
          margin-bottom: 1.5rem;
          padding-bottom: 0.5rem;
          border-bottom: 3px solid #3498db;
        }

        .diff-container {
          margin-top: 1rem;
        }

        .diff-part {
          display: flex;
          gap: 2rem;
          margin-bottom: 2rem;
          border: 1px solid #dee2e6;
          border-radius: 8px;
          overflow: hidden;
        }

        .diff-side {
          flex: 1;
          min-width: 0;
        }

        .diff-header {
          font-size: 1.2rem;
          font-weight: 600;
          padding: 1rem;
          margin: 0;
          text-align: center;
          color: white;
        }

        .diff-left .diff-header {
          background-color: #e74c3c;
        }

        .diff-right .diff-header {
          background-color: #27ae60;
        }

        .diff-content {
          padding: 1rem;
          background-color: #f8f9fa;
          min-height: 200px;
          overflow-x: auto;
        }

        .no-diff-message {
          text-align: center;
          padding: 4rem 2rem;
          background: white;
          border-radius: 12px;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        .no-diff-icon {
          font-size: 4rem;
          margin-bottom: 1rem;
        }

        .no-diff-message h2 {
          color: #27ae60;
          margin-bottom: 1rem;
          font-size: 2rem;
        }

        .no-diff-message p {
          font-size: 1.2rem;
          color: #6c757d;
        }

        .footer {
          text-align: center;
          padding: 2rem;
          color: #6c757d;
          margin-top: 2rem;
        }

        .footer a {
          color: #3498db;
          text-decoration: none;
          font-weight: 600;
        }

        .footer a:hover {
          text-decoration: underline;
        }

        @media (max-width: 768px) {
          .container {
            padding: 10px;
          }

          .header h1 {
            font-size: 2rem;
          }

          .diff-part {
            flex-direction: column;
            gap: 0;
          }

          .diff-side {
            border-bottom: 1px solid #dee2e6;
          }

          .diff-side:last-child {
            border-bottom: none;
          }
        }

        @media (prefers-color-scheme: dark) {
          body {
            background-color: #1a1a1a;
            color: #e0e0e0;
          }

          .table-section {
            background: #2d2d2d;
            border-color: #444;
          }

          .table-title {
            color: #f0f0f0;
          }

          .diff-content {
            background-color: #383838;
            color: #e0e0e0;
          }

          .no-diff-message {
            background: #2d2d2d;
          }
        }
      CSS
    end

    def diffy_css
      <<~CSS
        .diff {
          overflow: auto;
          border-radius: 6px;
        }

        .diff ul {
          background: #fff;
          overflow: auto;
          font-size: 13px;
          list-style: none;
          margin: 0;
          padding: 0;
          display: table;
          width: 100%;
          font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
        }

        .diff del, .diff ins {
          display: block;
          text-decoration: none;
        }

        .diff li {
          padding: 0;
          display: table-row;
          margin: 0;
          height: 1em;
        }

        .diff li.ins {
          background: #dfd;
          color: #080;
        }

        .diff li.del {
          background: #fee;
          color: #b00;
        }

        .diff li:hover {
          background: #ffc;
        }

        .diff del, .diff ins, .diff span {
          white-space: pre-wrap;
          font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
        }

        .diff del strong {
          font-weight: normal;
          background: #fcc;
        }

        .diff ins strong {
          font-weight: normal;
          background: #9f9;
        }

        .diff li.diff-comment {
          display: none;
        }

        .diff li.diff-block-info {
          background: none repeat scroll 0 0 gray;
        }

        @media (prefers-color-scheme: dark) {
          .diff ul {
            background: #2d2d2d;
            color: #e0e0e0;
          }

          .diff li.ins {
            background: #2d5a2d;
            color: #90ee90;
          }

          .diff li.del {
            background: #5a2d2d;
            color: #ffb3b3;
          }

          .diff li:hover {
            background: #4a4a00;
          }
        }
      CSS
    end
  end
end