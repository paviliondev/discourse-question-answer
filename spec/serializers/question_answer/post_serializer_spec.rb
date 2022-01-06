# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::PostSerializerExtension do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:answer) { Fabricate(:post, topic: topic, post_number: 2) }
  let(:comment) { Fabricate(:qa_comment, post: answer) }
  let(:topic_view) { TopicView.new(topic, user) }
  let(:up) { QuestionAnswerVote.directions[:up] }
  let(:guardian) { Guardian.new(user) }

  let(:serialized) do
    serializer = PostSerializer.new(answer, scope: guardian, root: false)
    serializer.topic_view = topic_view
    serializer.as_json
  end

  context 'qa enabled' do
    before do
      category.custom_fields['qa_enabled'] = true
      category.save!
      category.reload
      comment
    end

    it 'should return the right attributes' do
      QuestionAnswer::VoteManager.vote(answer, user, direction: up)

      expect(serialized[:qa_vote_count]).to eq(1)
      expect(serialized[:qa_user_voted_direction]).to eq(up)
      expect(serialized[:qa_enabled]).to eq(true)
      expect(serialized[:comments_count]).to eq(1)
      expect(serialized[:comments].first[:id]).to eq(comment.id)
    end
  end

  context 'qa disabled' do
    it 'should not include dependent_keys' do
      expect(serialized[:qa_vote_count]).to eq(nil)
      expect(serialized[:qa_user_voted_direction]).to eq(nil)
      expect(serialized[:comments_count]).to eq(nil)
      expect(serialized[:comments]).to eq(nil)
      expect(serialized[:qa_enabled]).to eq(false)
    end
  end
end
