# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::PostSerializerExtension do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic) }
  fab!(:comment) { Fabricate(:qa_comment, post: answer) }
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
      SiteSetting.qa_enabled = true
    end

    it 'should return the right attributes' do
      QuestionAnswer::VoteManager.vote(answer, user, direction: up)

      expect(serialized[:qa_vote_count]).to eq(1)
      expect(serialized[:qa_user_voted_direction]).to eq(up)
      expect(serialized[:comments_count]).to eq(1)
      expect(serialized[:comments].first[:id]).to eq(comment.id)
    end
  end

  context 'qa disabled' do
    before do
      SiteSetting.qa_enabled = false
    end

    it 'should not include dependent_keys' do
      expect(serialized[:qa_vote_count]).to eq(nil)
      expect(serialized[:qa_user_voted_direction]).to eq(nil)
      expect(serialized[:comments_count]).to eq(nil)
      expect(serialized[:comments]).to eq(nil)
    end
  end
end
