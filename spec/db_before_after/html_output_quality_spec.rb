# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe DbBeforeAfter::HtmlOutputAdapter, 'HTML Output Quality' do
  let(:tempfile) { Tempfile.new('test_output.html') }
  let(:adapter) { described_class.new(tempfile) }

  after { tempfile.close }

  describe 'HTML structure validation' do
    it 'generates valid HTML5 structure' do
      adapter.start_output
      adapter.write_title('users')
      adapter.write_diff_section('<div class="diff">left</div>', '<div class="diff">right</div>')
      adapter.close_section
      adapter.write_no_diff_message
      adapter.end_output
      
      tempfile.rewind
      content = tempfile.read
      
      # Basic HTML5 structure validation
      expect(content).to match(/<!DOCTYPE html>/)
      expect(content).to match(/<html lang="en">/)
      expect(content).to match(/<head>.*<\/head>/m)
      expect(content).to match(/<body>.*<\/body>/m)
      expect(content).to match(/<\/html>$/)
      
      # Meta tags validation
      expect(content).to include('<meta charset="UTF-8">')
      expect(content).to include('<meta name="viewport" content="width=device-width, initial-scale=1.0">')
      expect(content).to include('<title>Database Diff Report</title>')
    end

    it 'includes proper semantic HTML elements' do
      adapter.start_output
      adapter.write_title('users')
      adapter.write_diff_section('left content', 'right content')
      adapter.close_section
      adapter.end_output
      
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<header class="header">')
      expect(content).to include('<main class="main-content">')
      expect(content).to include('<section class="table-section">')
      expect(content).to include('<footer class="footer">')
      expect(content).to include('<h1>Database Diff Report</h1>')
      expect(content).to include('<h2 class="table-title">users</h2>')
      expect(content).to include('<h3 class="diff-header">Before</h3>')
      expect(content).to include('<h3 class="diff-header">After</h3>')
    end
  end

  describe 'CSS quality' do
    it 'includes modern CSS with proper selectors' do
      adapter.start_output
      tempfile.rewind
      content = tempfile.read
      
      # Modern CSS reset
      expect(content).to include('* {')
      expect(content).to include('box-sizing: border-box;')
      
      # Modern font stack
      expect(content).to include('font-family: -apple-system, BlinkMacSystemFont')
      
      # Responsive design
      expect(content).to include('@media (max-width: 768px)')
      
      # Dark mode support
      expect(content).to include('@media (prefers-color-scheme: dark)')
      
      # Flexbox layout
      expect(content).to include('display: flex')
      
      # Modern CSS properties
      expect(content).to include('border-radius:')
      expect(content).to include('box-shadow:')
      expect(content).to include('background: linear-gradient')
    end

    it 'provides proper accessibility features' do
      adapter.start_output
      tempfile.rewind
      content = tempfile.read
      
      # Color contrast considerations
      expect(content).to include('color: #333')
      expect(content).to include('color: white')
      
      # Focus states
      expect(content).to include(':hover')
      
      # Readable font sizes
      expect(content).to include('font-size: 2.5rem')
      expect(content).to include('font-size: 1.8rem')
      expect(content).to include('font-size: 1.2rem')
      
      # Line height for readability
      expect(content).to include('line-height: 1.6')
    end
  end

  describe 'responsive design' do
    it 'includes mobile-first responsive styles' do
      adapter.start_output
      tempfile.rewind
      content = tempfile.read
      
      # Mobile viewport meta tag
      expect(content).to include('<meta name="viewport" content="width=device-width, initial-scale=1.0">')
      
      # Mobile-specific styles
      expect(content).to include('@media (max-width: 768px)')
      expect(content).to include('flex-direction: column')
      expect(content).to include('padding: 10px')
      expect(content).to include('font-size: 2rem')
    end
  end

  describe 'dark mode support' do
    it 'includes dark mode CSS variables' do
      adapter.start_output
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('@media (prefers-color-scheme: dark)')
      expect(content).to include('background-color: #1a1a1a')
      expect(content).to include('background: #2d2d2d')
      expect(content).to include('color: #e0e0e0')
    end
  end

  describe 'diff visualization quality' do
    it 'provides clear visual distinction between before and after' do
      adapter.start_output
      adapter.write_title('users')
      adapter.write_diff_section('before content', 'after content')
      adapter.close_section
      adapter.end_output
      
      tempfile.rewind
      content = tempfile.read
      
      # Clear headers
      expect(content).to include('<h3 class="diff-header">Before</h3>')
      expect(content).to include('<h3 class="diff-header">After</h3>')
      
      # Color-coded headers
      expect(content).to include('background-color: #e74c3c') # Red for before
      expect(content).to include('background-color: #27ae60') # Green for after
      
      # Proper content structure
      expect(content).to include('<div class="diff-content">before content</div>')
      expect(content).to include('<div class="diff-content">after content</div>')
    end

    it 'includes proper diff styling for code content' do
      adapter.start_output
      tempfile.rewind
      content = tempfile.read
      
      # Monospace font for code
      expect(content).to include("font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace")
      
      # Diff-specific styling
      expect(content).to include('.diff li.ins')
      expect(content).to include('.diff li.del')
      expect(content).to include('background: #dfd') # Addition background
      expect(content).to include('background: #fee') # Deletion background
      
      # Syntax highlighting support
      expect(content).to include('.diff del strong')
      expect(content).to include('.diff ins strong')
    end
  end

  describe 'no diff message quality' do
    it 'provides user-friendly no changes message' do
      adapter.write_no_diff_message
      tempfile.rewind
      content = tempfile.read
      
      expect(content).to include('<div class="no-diff-message">')
      expect(content).to include('<div class="no-diff-icon">✅</div>')
      expect(content).to include('<h2>No Changes Detected</h2>')
      expect(content).to include('<p>The database state remained unchanged during the operation.</p>')
    end

    it 'styles no diff message with proper visual hierarchy' do
      adapter.start_output
      tempfile.rewind
      content = tempfile.read
      
      # Centered styling
      expect(content).to include('text-align: center')
      
      # Proper spacing
      expect(content).to include('padding: 4rem 2rem')
      expect(content).to include('margin-bottom: 1rem')
      
      # Visual emphasis
      expect(content).to include('font-size: 4rem') # Icon size
      expect(content).to include('font-size: 2rem') # Heading size
      expect(content).to include('color: #27ae60') # Success color
    end
  end

  describe 'performance considerations' do
    it 'generates lightweight HTML without external dependencies' do
      adapter.start_output
      adapter.write_title('users')
      adapter.write_diff_section('content', 'content')
      adapter.close_section
      adapter.end_output
      
      tempfile.rewind
      content = tempfile.read
      
      # No external CSS or JS dependencies
      expect(content).not_to include('<link')
      expect(content).not_to include('<script')
      
      # No external resource loading (except for footer link)
      external_links = content.scan(/https?:\/\//).size
      expect(external_links).to eq(1) # Only the footer link to GitHub
      
      # All styles are inline
      expect(content).to include('<style>')
      expect(content).to include('</style>')
    end
  end
end