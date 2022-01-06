# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswerCommentSerializer do
  fab!(:tag) { Fabricate(:tag) }
  fab!(:topic) { Fabricate(:topic, tags: [tag]) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:qa_comment) { Fabricate(:qa_comment, post: post) }
  let(:serializer) { described_class.new(qa_comment) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
  end

  it 'returns the right attributes' do
    serilized_comment = serializer.as_json[:question_answer_comment]

    expect(serilized_comment[:id]).to eq(qa_comment.id)
    expect(serilized_comment[:created_at]).to eq(qa_comment.created_at)
    expect(serilized_comment[:cooked]).to eq(qa_comment.cooked)
    expect(serilized_comment[:name]).to eq(qa_comment.user.name)
    expect(serilized_comment[:username]).to eq(qa_comment.user.username)
  end
end
