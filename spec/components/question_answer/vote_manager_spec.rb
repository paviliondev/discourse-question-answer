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
      QuestionAnswer::VoteManager.vote(post, user, direction: up)

      expect(QuestionAnswerVote.exists?(post: post, user: user, direction: up))
        .to eq(true)

      expect(post.qa_vote_count).to eq(1)
    end

    it 'can create a downvote' do
      QuestionAnswer::VoteManager.vote(post, user, direction: down)

      expect(QuestionAnswerVote.exists?(post: post, user: user, direction: down))
        .to eq(true)

      expect(post.qa_vote_count).to eq(-1)
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

      QuestionAnswer::VoteManager.remove_vote(vote.post, vote.user)

      expect(QuestionAnswerVote.exists?(id: vote.id)).to eq(false)
      expect(vote.post.qa_vote_count).to eq(0)
    end

    it "should remove a user's upvote" do
      vote = QuestionAnswer::VoteManager.vote(post, Fabricate(:user), direction: up)
      vote_2 = QuestionAnswer::VoteManager.vote(post, Fabricate(:user), direction: up)
      vote_3 = QuestionAnswer::VoteManager.vote(post, user, direction: down)

      expect do
        QuestionAnswer::VoteManager.remove_vote(post, user)
      end.to change { vote.post.reload.qa_vote_count }.from(1).to(2)

      expect(QuestionAnswerVote.exists?(id: vote_3.id)).to eq(false)
    end
  end
end
