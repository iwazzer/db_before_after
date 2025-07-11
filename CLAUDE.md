# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby gem called `db_before_after` that generates HTML diff reports showing database changes before and after executing a use case. The tool takes database snapshots, waits for user action, then compares the results.

## Common Commands

### Development Setup
```bash
bin/setup              # Install dependencies and setup development environment
bin/console            # Start interactive Ruby console with gem loaded
```

### Testing
```bash
rake spec              # Run all RSpec tests
rspec                  # Alternative way to run tests
```

### Building and Installing
```bash
rake build             # Build gem into pkg/ directory
rake install           # Build and install gem locally
rake install:local     # Install without network access
```

### Main Executable
```bash
db_diff -u <user> -p <password> -d <database> [-h host] [-P port] [-e encoding] [-s suffix]
```

## Code Architecture

### Core Components

**DbBeforeAfter::DbDiff** (`lib/db_before_after/db_diff.rb`)
- Main class that orchestrates the entire diff process
- Handles database connection via mysql2 gem
- Generates HTML output with side-by-side diff visualization
- Uses Diffy gem for diff generation and ULID for unique file naming

**Database Operations**
- Connects to MySQL using prepared statements for security
- Reads all tables and their schema information
- Handles different data types (datetime formatting, blob MD5 hashing)
- Takes complete database snapshots for comparison

**Output Generation**
- Creates HTML files with embedded CSS styling
- Uses `/tmp` directory (or Rails.root if in Rails environment)
- Automatically copies file path to clipboard for easy access
- Generates unique filenames using ULID

### Key Dependencies

- **mysql2**: Database connectivity (MySQL only)
- **diffy**: HTML diff generation with CSS styling
- **ulid**: Unique identifier generation for output files
- **clipboard**: Automatic clipboard copying of output paths

### File Structure

- `exe/db_diff`: Command-line executable script
- `lib/db_before_after/db_diff.rb`: Core functionality
- `lib/db_before_after/version.rb`: Version definition
- `sig/`: RBS type definitions for the gem

## Database Configuration

The gem accepts database connection parameters via:
- Command-line arguments (primary method)
- Environment variables: `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE`, `DB_PORT`, `DB_ENCODING`

Only MySQL is currently supported via the mysql2 gem.

## Development Notes

- Ruby 3.3.5 is specified in `.ruby-version`
- Uses RSpec for testing with minimal coverage currently
- No linting tools (RuboCop, etc.) are currently configured
- RBS type definitions are provided in the `sig/` directory
- The gem is in early development with room for expanded testing and tooling