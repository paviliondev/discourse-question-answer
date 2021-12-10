# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionAnswer::CommentsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:tag) { Fabricate(:tag) }

  fab!(:topic) do
    Fabricate(:topic, category: category).tap do |t|
      t.tags << tag
    end
  end

  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic) }
  fab!(:comment) { Fabricate(:post, topic: topic, reply_to_post_number: answer.post_number) }
  fab!(:comment_2) { Fabricate(:post, topic: topic, reply_to_post_number: answer.post_number) }
  fab!(:comment_3) { Fabricate(:post, topic: topic, reply_to_post_number: answer.post_number) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
  end

  describe '#load_comments' do
    it 'returns the right response when Q&A is not enabled' do
      SiteSetting.qa_enabled = false

      get "/qa/comments.json", params: {
        post_id: answer.id, post_number: comment.post_number
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when user is not allowed to view post' do
      category.update!(read_restricted: true)

      get "/qa/comments.json", params: {
        post_id: answer.id, post_number: comment.post_number
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when post_id is invalid' do
      get "/qa/comments.json", params: {
        post_id: -999999, post_number: comment.post_number
      }

      expect(response.status).to eq(404)
    end

    it 'returns the right response' do
      get "/qa/comments.json", params: {
        post_id: answer.id, post_number: comment.post_number
      }

      expect(response.status).to eq(200)
      payload = response.parsed_body

      expect(payload["comments"].length).to eq(2)

      comment = payload["comments"].first

      expect(comment["id"]).to eq(comment_2.id)
      expect(comment["post_number"]).to eq(comment_2.post_number)
      expect(comment["name"]).to eq(comment_2.user.name)
      expect(comment["username"]).to eq(comment_2.user.username)
      expect(comment["avatar_template"]).to eq(comment_2.user.avatar_template)
      expect(comment["created_at"].present?).to eq(true)
      expect(comment["cooked"]).to eq(comment_2.cooked)

      comment = payload["comments"].last

      expect(comment["id"]).to eq(comment_3.id)
      expect(comment["post_number"]).to eq(comment_3.post_number)
    end
  end

  describe '#create' do
    it 'returns the right response when Q&A is not enabled' do
      SiteSetting.qa_enabled = false

      post "/qa/comments.json", params: {
        post_id: answer.id
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when user is not allowed to create post' do
      category.update!(read_restricted: true)

      post "/qa/comments.json", params: {
        post_id: answer.id,
        raw: "this is some content",
        typing_duration: 0
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when post_id is invalid' do
      post "/qa/comments.json", params: {
        post_id: -999999,
        raw: "this is some content",
        typing_duration: 0
      }

      expect(response.status).to eq(404)
    end

    it 'returns the right response after creating a new comment' do
      sign_in(user)

      expect do
        post "/qa/comments.json", params: {
          post_id: answer.id,
          raw: "this is some content",
          typing_duration: 0
        }
      end.to change { Post.count }.by(1)

      expect(response.status).to eq(200)

      payload = response.parsed_body
      comment = Post.last

      expect(payload["id"]).to eq(comment.id)
      expect(payload["name"]).to eq(user.name)
      expect(payload["username"]).to eq(user.username)
      expect(payload["avatar_template"]).to eq(user.avatar_template)
      expect(payload["cooked"]).to eq(comment.cooked)
    end
  end
end
