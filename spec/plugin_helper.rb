# frozen_string_literal: true

require 'simplecov'

SimpleCov.configure do
  add_filter do |src|
    src.filename !~ /discourse-question-answer/ ||
    src.filename =~ /spec/ ||
    src.filename =~ /db/ ||
    src.filename =~ /plugin\.rb/
  end
end
