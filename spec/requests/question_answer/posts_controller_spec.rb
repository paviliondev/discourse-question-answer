# frozen_string_literal: true

require 'rails_helper'

describe PostsController do
  let(:user) { Fabricate(:user) }

  describe '#create' do
    before do
      sign_in(user)
      SiteSetting.qa_enabled = true
    end

    it 'sets the question subtype when the is_question param is set to true' do
      post "/posts.json", params: {
        raw: 'this is a test question',
        title: 'this is the title for the question topic',
        is_question: true,
      }
    end

    it 'only sets the question subtype on regular topics' do
      another_user = Fabricate(:user)
      post "/posts.json", params: {
        raw: 'this is a test question',
        title: 'this is the title for the question topic',
        is_question: true,
        target_recipients: another_user.username,
        archetype: Archetype.private_message
      }

      expect(response.status).to eq(200)

      created_topic = Topic.last
      expect(created_topic.subtype).not_to eq('question')
    end

    it 'preserves the subtype when a topic gets queued' do
      SiteSetting.approve_post_count = 1

      post "/posts.json", params: {
        raw: 'this is the test content',
        title: 'this is the test title for the topic',
        is_question: true,
      }

      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(parsed["action"]).to eq("enqueued")

      rp = ReviewableQueuedPost.find_by(created_by: user)
      expect(rp).to be_present

      result = rp.perform(Discourse.system_user, :approve_post)
      expect(result.created_post.topic.subtype).to eq('question')
    end
  end
end
