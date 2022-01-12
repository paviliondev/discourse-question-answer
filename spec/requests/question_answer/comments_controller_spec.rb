# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionAnswer::CommentsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:tag) { Fabricate(:tag) }
  fab!(:group) { Fabricate(:group) }

  fab!(:topic) do
    Fabricate(:topic, category: category).tap do |t|
      t.tags << tag
    end
  end

  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic) }
  let(:comment) { Fabricate(:qa_comment, post: answer) }
  let(:comment_2) { Fabricate(:qa_comment, post: answer) }
  let(:comment_3) { Fabricate(:qa_comment, post: answer) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
    comment
    comment_2
    comment_3
  end

  describe '#load_comments' do
    it 'returns the right response when QnA is not enabled' do
      SiteSetting.qa_enabled = false

      get "/qa/comments.json", params: {
        post_id: answer.id, last_comment_id: comment.id
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when user is not allowed to view post' do
      category.update!(read_restricted: true)

      get "/qa/comments.json", params: {
        post_id: answer.id, last_comment_id: comment.id
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when post_id is invalid' do
      get "/qa/comments.json", params: {
        post_id: -999999, last_comment_id: comment.id
      }

      expect(response.status).to eq(404)
    end

    it 'returns the right response' do
      get "/qa/comments.json", params: {
        post_id: answer.id, last_comment_id: comment.id
      }

      expect(response.status).to eq(200)
      payload = response.parsed_body

      expect(payload["comments"].length).to eq(2)

      comment = payload["comments"].first

      expect(comment["id"]).to eq(comment_2.id)
      expect(comment["name"]).to eq(comment_2.user.name)
      expect(comment["username"]).to eq(comment_2.user.username)
      expect(comment["created_at"].present?).to eq(true)
      expect(comment["cooked"]).to eq(comment_2.cooked)

      comment = payload["comments"].last

      expect(comment["id"]).to eq(comment_3.id)
    end
  end

  describe '#create' do
    before do
      sign_in(user)
    end

    it 'returns the right response when Q&A is not enabled' do
      SiteSetting.qa_enabled = false

      post "/qa/comments.json", params: {
        post_id: answer.id,
        raw: "this is some comment"
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when user is not allowed to create post' do
      category.set_permissions(group => :readonly)
      category.save!

      post "/qa/comments.json", params: {
        post_id: answer.id,
        raw: "this is some content",
      }

      expect(response.status).to eq(403)
    end

    it 'returns the right response when post_id is invalid' do
      post "/qa/comments.json", params: {
        post_id: -999999,
        raw: "this is some content",
      }

      expect(response.status).to eq(404)
    end

    it 'returns the right response after creating a new comment' do
      expect do
        post "/qa/comments.json", params: {
          post_id: answer.id,
          raw: "this is some content",
        }
      end.to change { QuestionAnswerComment.count }.by(1)

      expect(response.status).to eq(200)

      payload = response.parsed_body
      comment = QuestionAnswerComment.last

      expect(payload["id"]).to eq(comment.id)
      expect(payload["name"]).to eq(user.name)
      expect(payload["username"]).to eq(user.username)
      expect(payload["cooked"]).to eq(comment.cooked)
    end
  end

  describe '#destroy' do
    it 'should return 403 for an anon user' do
      delete "/qa/comments.json", params: { comment_id: comment.id }

      expect(response.status).to eq(403)
    end

    it 'should return 404 when comment_id param given does not exist' do
      sign_in(comment.user)

      delete "/qa/comments.json", params: { comment_id: -99999 }

      expect(response.status).to eq(404)
    end

    it 'should return 403 when trying to delete a comment on a post the user cannot see' do
      sign_in(comment.user)

      category.set_permissions(group => :readonly)
      category.save!

      delete "/qa/comments.json", params: { comment_id: comment.id }

      expect(response.status).to eq(403)
    end

    it "should return 403 when a user is trying to delete another user's comment" do
      sign_in(Fabricate(:user))

      delete "/qa/comments.json", params: { comment_id: comment.id }

      expect(response.status).to eq(403)
    end

    it "should allow an admin to delete a comment of another user" do
      sign_in(Fabricate(:admin))

      delete "/qa/comments.json", params: { comment_id: comment.id }

      expect(response.status).to eq(200)
      expect(QuestionAnswerComment.exists?(id: comment.id)).to eq(false)
    end

    it "should allow users to delete their own comment" do
      sign_in(comment.user)

      delete "/qa/comments.json", params: { comment_id: comment.id }

      expect(response.status).to eq(200)
      expect(QuestionAnswerComment.exists?(id: comment.id)).to eq(false)
    end
  end
end
