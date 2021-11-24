# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::PostCreatorExtension do
  fab!(:user) { Fabricate(:user) }

  it 'should assign post_opts to guardian' do
    test_string = 'Test string'
    opts = { raw: test_string }
    post_creator = PostCreator.new(user, opts)

    post_creator.valid?

    expect(post_creator.guardian.post_opts[:raw]).to eq(test_string)
  end
end
