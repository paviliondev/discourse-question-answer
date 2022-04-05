# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionAnswer::CommentsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:group) { Fabricate(:group) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category, subtype: Topic::QA_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic) }
  let(:comment) { Fabricate(:qa_comment, post: answer) }
  let(:comment_2) { Fabricate(:qa_comment, post: answer) }
  let(:comment_3) { Fabricate(:qa_comment, post: answer) }

  before do
    SiteSetting.qa_enabled = true
    comment
    comment_2
    comment_3
  end

  describe '#load_comments' do
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

    it 'publishes a comment created MessageBus message when a new comment is created' do
      message = MessageBus.track_publish("/topic/#{answer.topic_id}") do
        expect do
          post "/qa/comments.json", params: {
            post_id: answer.id,
            raw: "this is some content",
          }

          expect(response.status).to eq(200)
        end.to change { answer.reload.question_answer_comments.count }.by(1)
      end.first

      comment = answer.question_answer_comments.last
      payload = message[:data]

      expect(payload[:comment][:id]).to eq(comment.id)
      expect(payload[:comment][:user_id]).to eq(user.id)
      expect(payload[:comment][:name]).to eq(user.name)
      expect(payload[:comment][:username]).to eq(user.username)
      expect(payload[:comment][:created_at]).to be_present
      expect(payload[:comment][:raw]).to eq("this is some content")
      expect(payload[:comment][:cooked]).to eq("<p>this is some content</p>")
      expect(payload[:comment][:qa_vote_count]).to eq(0)
      expect(payload[:comment][:user_voted]).to eq(false)
    end

    it 'publishes a notification when a new comment is created' do
      answer.user.update!(last_seen_at: Time.zone.now) # User has to be seen recently to trigger notification alert message

      message = MessageBus.track_publish("/notification-alert/#{answer.user_id}") do
        expect do
          post "/qa/comments.json", params: {
            post_id: answer.id,
            raw: "this is some content",
          }

          expect(response.status).to eq(200)
        end.to change { answer.user.notifications.count }.by(1)
      end.first

      notification = answer.user.notifications.last
      comment = QuestionAnswerComment.last

      expect(notification.notification_type).to eq(Notification.types[:question_answer_user_commented])
      expect(notification.user_id).to eq(answer.user_id)
      expect(notification.post_number).to eq(answer.post_number)
      expect(notification.topic_id).to eq(answer.topic_id)

      expect(notification.data).to eq({
        qa_comment_id: comment.id,
        display_username: user.username
      }.to_json)

      expect(message.data[:notification_type]).to eq(Notification.types[:question_answer_user_commented])
    end

    it 'returns the right response after creating a new comment' do
      expect do
        post "/qa/comments.json", params: {
          post_id: answer.id,
          raw: "this is some content",
        }

        expect(response.status).to eq(200)
      end.to change { answer.reload.question_answer_comments.count }.by(1)

      payload = response.parsed_body
      comment = answer.question_answer_comments.last

      expect(payload["id"]).to eq(comment.id)
      expect(payload["name"]).to eq(user.name)
      expect(payload["username"]).to eq(user.username)
      expect(payload["cooked"]).to eq(comment.cooked)
    end
  end

  describe '#update' do
    it 'should return 403 for an anon user' do
      put "/qa/comments.json", params: {
        comment_id: comment.id,
        raw: 'this is some new raw'
      }

      expect(response.status).to eq(403)
    end

    it 'should return 404 when comment_id is not associated to a valid record' do
      sign_in(comment.user)

      put "/qa/comments.json", params: {
        comment_id: -999999,
        raw: 'this is some new raw'
      }

      expect(response.status).to eq(404)
    end

    it 'should return 403 when trying to update a comment on a post the user cannot see' do
      sign_in(comment.user)

      category.set_permissions(group => :readonly)
      category.save!

      put "/qa/comments.json", params: {
        comment_id: comment.id,
        raw: 'this is some new raw'
      }

      expect(response.status).to eq(403)
    end

    it 'should return 403 when a user is trying to update the comment of another user' do
      sign_in(Fabricate(:user))

      put "/qa/comments.json", params: {
        comment_id: comment.id,
        raw: 'this is some new raw'
      }

      expect(response.status).to eq(403)
    end

    it 'should allow an admin to update the comment' do
      sign_in(admin)

      put "/qa/comments.json", params: {
        comment_id: comment.id,
        raw: 'this is some new raw'
      }

      expect(response.status).to eq(200)

      body = response.parsed_body

      expect(body["raw"]).to eq("this is some new raw")
      expect(body["cooked"]).to eq("<p>this is some new raw</p>")
    end

    it 'should allow users to update their own comment' do
      sign_in(comment.user)

      put "/qa/comments.json", params: {
        comment_id: comment.id,
        raw: 'this is some new raw'
      }

      expect(response.status).to eq(200)

      body = response.parsed_body

      expect(body["raw"]).to eq("this is some new raw")
      expect(body["cooked"]).to eq("<p>this is some new raw</p>")
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
      sign_in(admin)

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
