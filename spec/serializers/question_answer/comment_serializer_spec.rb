# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::CommentSerializer do
  fab!(:post) { Fabricate(:post) }
  let(:serializer) { described_class.new(post) }

  it 'returns the right attributes' do
    serilized_comment = serializer.as_json[:comment]

    expect(serilized_comment[:id]).to eq(post.id)
    expect(serilized_comment[:post_number]).to eq(post.post_number)
    expect(serilized_comment[:created_at]).to eq(post.created_at)
    expect(serilized_comment[:cooked]).to eq(post.cooked)
    expect(serilized_comment[:name]).to eq(post.user.name)
    expect(serilized_comment[:username]).to eq(post.user.username)
  end
end
