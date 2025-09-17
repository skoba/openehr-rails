# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Principle

Follow the TDD framework as advocated by t-wada:
- 🔴 Red: Write a failing test
- 🟢 Green: Write the minimal implementation to pass the test
- 🔵 Refactor: Improve the code while keeping tests green
- Take small steps
- Start with fake implementation (hard-coded values)
- Use triangulation to generalize
- Direct implementation is OK when the solution is obvious
- Keep the test list constantly updated
- Write tests for areas of concern first
- opt files must not be changed automatically.


## Project Overview

This is `openehr-rails`, a Rails extension gem for generating scaffolds and components based on openEHR archetypes. It provides Rails generators to create models, controllers, views, and other components from ADL (Archetype Definition Language) formatted archetype files used in healthcare informatics.

## Key Commands

**Testing:**
- `rake spec` - Run all RSpec tests
- `rake` - Default task runs specs
- `bundle exec rspec spec/path/to/specific_spec.rb` - Run specific test file

**Development:**
- `bundle install` - Install dependencies
- `bundle exec rake` - Run tests via bundler
- `bundle exec guard` - Run Guard for automated testing (requires guard-rspec)

**Gem Development:**
- `rake build` - Build the gem (via bundler/gem_tasks)
- `rake install` - Install the gem locally
- `rake release` - Release the gem

## Architecture & Structure

### Core Components

1. **Generators Framework** (`lib/generators/openehr/`):
   - Base class: `Openehr::Generators::ArchetypedBase` in `lib/generators/openehr.rb`
   - All generators inherit from this base and work with openEHR archetypes
   - Generators parse ADL files using `OpenEHR::Parser::ADLParser`

2. **Generator Types**:
   - `install/` - Initial setup generator
   - `scaffold/` - Full MVC scaffold from archetype
   - `model/` - Model generation
   - `controller/` - Controller generation
   - `migration/` - Database migration generation
   - `assets/`, `helper/`, `i18n/` - Supporting component generators

3. **Key Dependencies**:
   - `openehr` gem - Core openEHR Ruby implementation
   - `ckm_client` - Clinical Knowledge Manager client
   - `rails` - Rails framework integration

### Generator Base Class Pattern

All generators extend `ArchetypedBase` which provides:
- Archetype parsing from ADL files
- Standard naming conventions (archetype_name, controller_name, model_name)
- Path helpers for archetype storage (`app/archetypes`)
- Class name transformations (underscore/camelize)

### Testing Structure

- Uses RSpec with `ammeter` gem for generator testing
- Test archetypes in `spec/templates/` (e.g., blood_pressure.v1.adl)
- Generator specs follow pattern: `spec/generators/openehr/[generator_name]/`
- Component specs in `spec/rcomponents/` for R* classes

## Development Notes

- Ruby 3.0+ required (tested with Ruby 3.4)
- Rails 7.0+ and Rails 8.x supported
- URI compatibility workaround implemented for Ruby 3.4
- Guard setup available for TDD workflow
- RuboCop Rails linting configured
- SimpleCov for test coverage
- Most tests are currently marked as pending (xdescribe/xit)