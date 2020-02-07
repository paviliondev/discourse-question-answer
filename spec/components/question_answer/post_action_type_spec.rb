# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::PostActionTypeExtension do
  it 'should recognize vote action' do
    expect(PostActionType.types[:vote]).to eq(100)
  end

  it 'should exclude vote from public_types' do
    expect(PostActionType.public_types.include?(:vote)).to eq(false)
  end
end
