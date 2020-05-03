# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::CategoryCustomFieldExtension do
  it 'should call callback correctly' do
    custom_field = CategoryCustomField.new(name: 'qa_enabled')

    expect(custom_field.qa_enabled_changed).to eq(true)

    custom_field.name = 'random_name'

    expect(custom_field.qa_enabled_changed).to eq(false)
  end
end

describe QuestionAnswer::CategoryExtension do
  fab!(:category) { Fabricate(:category) }
  let(:fields) do
    %w[
      qa_enabled
      qa_one_to_many
      qa_disable_like_on_answers
      qa_disable_like_on_questions
      qa_disable_like_on_comments
    ]
  end

  it 'should cast custom fields correctly' do
    fields.each do |f|
      expect(category.send(f)).to eq(false)
    end

    fields.each do |f|
      category.custom_fields[f] = true
    end

    category.save_custom_fields
    category.reload

    fields.each do |f|
      expect(category.send(f)).to eq(true)
    end
  end
end
