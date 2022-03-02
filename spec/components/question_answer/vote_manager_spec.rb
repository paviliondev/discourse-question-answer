# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::VoteManager do
  fab!(:user)  { Fabricate(:user) }
  fab!(:user_2)  { Fabricate(:user) }
  fab!(:user_3)  { Fabricate(:user) }
  fab!(:post)  { Fabricate(:post, post_number: 2) }
  fab!(:tag)  { Fabricate(:tag) }
  fab!(:up) { QuestionAnswerVote.directions[:up] }
  fab!(:down) { QuestionAnswerVote.directions[:down] }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
    post.topic.tags << tag
  end

  describe '.vote' do
    it 'can create an upvote' do
      message = MessageBus.track_publish("/topic/#{post.topic_id}") do
        QuestionAnswer::VoteManager.vote(post, user, direction: up)
      end.first

      expect(QuestionAnswerVote.exists?(votable: post, user: user, direction: up))
        .to eq(true)

      expect(post.qa_vote_count).to eq(1)

      expect(message.data[:id]).to eq(post.id)
      expect(message.data[:qa_user_voted_id]).to eq(user.id)
      expect(message.data[:qa_vote_count]).to eq(1)
      expect(message.data[:qa_user_voted_direction]).to eq(up)
      expect(message.data[:qa_has_votes]).to eq(true)
    end

    it 'can create a downvote' do
      message = MessageBus.track_publish("/topic/#{post.topic_id}") do
        QuestionAnswer::VoteManager.vote(post, user, direction: down)
      end.first

      expect(QuestionAnswerVote.exists?(votable: post, user: user, direction: down))
        .to eq(true)

      expect(post.qa_vote_count).to eq(-1)

      expect(message.data[:id]).to eq(post.id)
      expect(message.data[:qa_user_voted_id]).to eq(user.id)
      expect(message.data[:qa_vote_count]).to eq(-1)
      expect(message.data[:qa_user_voted_direction]).to eq(down)
      expect(message.data[:qa_has_votes]).to eq(true)
    end

    it 'can change an upvote to a downvote' do
      QuestionAnswer::VoteManager.vote(post, user, direction: up)
      QuestionAnswer::VoteManager.vote(post, user_2, direction: up)
      QuestionAnswer::VoteManager.vote(post, user, direction: down)

      expect(post.qa_vote_count).to eq(0)
    end

    it 'can change a downvote to upvote' do
      QuestionAnswer::VoteManager.vote(post, user, direction: down)
      QuestionAnswer::VoteManager.vote(post, user_2, direction: down)
      QuestionAnswer::VoteManager.vote(post, user_3, direction: down)
      QuestionAnswer::VoteManager.vote(post, user, direction: up)

      expect(post.qa_vote_count).to eq(-1)
    end
  end

  describe '.remove_vote' do
    it "should remove a user's upvote" do
      vote = QuestionAnswer::VoteManager.vote(post, user, direction: up)

      message = MessageBus.track_publish("/topic/#{post.topic_id}") do
        QuestionAnswer::VoteManager.remove_vote(vote.votable, vote.user)
      end.first

      expect(QuestionAnswerVote.exists?(id: vote.id)).to eq(false)
      expect(vote.votable.qa_vote_count).to eq(0)

      expect(message.data[:id]).to eq(post.id)
      expect(message.data[:qa_user_voted_id]).to eq(user.id)
      expect(message.data[:qa_vote_count]).to eq(0)
      expect(message.data[:qa_user_voted_direction]).to eq(nil)
      expect(message.data[:qa_has_votes]).to eq(false)
    end

    it "should remove a user's downvote" do
      vote = QuestionAnswer::VoteManager.vote(post, Fabricate(:user), direction: up)
      vote_2 = QuestionAnswer::VoteManager.vote(post, Fabricate(:user), direction: up)
      vote_3 = QuestionAnswer::VoteManager.vote(post, user, direction: down)

      message = MessageBus.track_publish("/topic/#{post.topic_id}") do
        expect do
          QuestionAnswer::VoteManager.remove_vote(post, user)
        end.to change { vote.votable.reload.qa_vote_count }.from(1).to(2)
      end.first

      expect(QuestionAnswerVote.exists?(id: vote_3.id)).to eq(false)
    end
  end
end
