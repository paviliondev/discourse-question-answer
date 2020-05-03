# frozen_string_literal: true

require 'simplecov'

SimpleCov.configure do
  add_filter do |src|
    src.filename !~ /discourse-question-answer/ ||
    src.filename =~ /spec/ ||
    src.filename =~ /db/
  end
end
