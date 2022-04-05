# frozen_string_literal: true

require 'rails_helper'

describe TopicView do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }
  fab!(:post) { create_post(topic: topic) }

  fab!(:answer) { create_post(topic: topic) }
  fab!(:answer_2) { create_post(topic: topic) }
  let(:comment) { Fabricate(:qa_comment, post: answer) }
  let(:comment_2) { Fabricate(:qa_comment, post: answer) }
  let(:comment_3) { Fabricate(:qa_comment, post: post) }
  let(:vote) { Fabricate(:qa_vote, votable: answer, user: user) }

  let(:vote_2) do
    Fabricate(:qa_vote,
      votable: answer_2,
      user: user,
      direction: QuestionAnswerVote.directions[:down]
    )
  end

  before do
    SiteSetting.qa_enabled = true
    vote
    vote_2
    comment
    comment_2
    comment_3
  end

  it 'does not preload Q&A related records for non-Q&A topics' do
    topic_2 = Fabricate(:topic)
    topic_2_post = Fabricate(:post, topic: topic_2)
    Fabricate(:post, topic: topic_2, reply_to_post_number: topic_2_post.post_number)

    topic_view = TopicView.new(topic_2, user)

    expect(topic_view.comments).to eq(nil)
    expect(topic_view.comments_counts).to eq(nil)
    expect(topic_view.posts_user_voted).to eq(nil)
  end

  it "should preload comments, comments count, user voted status for a given topic" do
    QuestionAnswer::VoteManager.vote(comment, user)
    QuestionAnswer::VoteManager.vote(comment_2, comment_2.user)

    topic_view = TopicView.new(topic, user)

    expect(topic_view.comments[answer.id].map(&:id)).to contain_exactly(comment.id, comment_2.id)
    expect(topic_view.comments[post.id].map(&:id)).to contain_exactly(comment_3.id)

    expect(topic_view.comments_counts[answer.id]).to eq(2)
    expect(topic_view.comments_counts[post.id]).to eq(1)

    expect(topic_view.posts_user_voted).to eq({
      answer.id => QuestionAnswerVote.directions[:up],
      answer_2.id => QuestionAnswerVote.directions[:down]
    })

    expect(topic_view.comments_user_voted).to eq({
      comment.id => true
    })
  end

  it "should respect Topic::PRELOAD_COMMENTS_COUNT when loading initial comments" do
    stub_const(TopicView, "PRELOAD_COMMENTS_COUNT", 1) do
      topic_view = TopicView.new(topic, user)

      expect(topic_view.comments[answer.id].map(&:id)).to contain_exactly(comment.id)
      expect(topic_view.comments_counts[answer.id]).to eq(2)
    end
  end

  it "should preload the right comments even if comments have been deleted" do
    comment_4 = Fabricate(:qa_comment, post: answer)
    comment.trash!

    stub_const(TopicView, "PRELOAD_COMMENTS_COUNT", 2) do
      topic_view = TopicView.new(topic, user)

      expect(topic_view.comments[answer.id].map(&:id)).to contain_exactly(comment_2.id, comment_4.id)
      expect(topic_view.comments_counts[answer.id]).to eq(2)
    end
  end

  describe '#filter_posts_near' do
    fab!(:topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }
    fab!(:post) { create_post(topic: topic) }

    fab!(:answer_plus_2_votes) do
      create_post(topic: topic).tap do |p|
        QuestionAnswer::VoteManager.vote(p, Fabricate(:user), direction: QuestionAnswerVote.directions[:up])
        QuestionAnswer::VoteManager.vote(p, Fabricate(:user), direction: QuestionAnswerVote.directions[:up])
      end
    end

    fab!(:answer_minus_2_votes) do
      create_post(topic: topic).tap do |p|
        QuestionAnswer::VoteManager.vote(p, Fabricate(:user), direction: QuestionAnswerVote.directions[:down])
        QuestionAnswer::VoteManager.vote(p, Fabricate(:user), direction: QuestionAnswerVote.directions[:down])
      end
    end

    fab!(:answer_minus_1_vote) do
      create_post(topic: topic).tap do |p|
        QuestionAnswer::VoteManager.vote(p, Fabricate(:user), direction: QuestionAnswerVote.directions[:down])
      end
    end

    fab!(:answer_0_votes) { create_post(topic: topic) }

    fab!(:answer_plus_1_vote_deleted) do
      create_post(topic: topic).tap do |p|
        QuestionAnswer::VoteManager.vote(p, Fabricate(:user), direction: QuestionAnswerVote.directions[:up])
        p.trash!
      end
    end

    fab!(:answer_plus_1_vote) do
      create_post(topic: topic).tap do |p|
        QuestionAnswer::VoteManager.vote(p, Fabricate(:user), direction: QuestionAnswerVote.directions[:up])
      end
    end

    def topic_view_near(post)
      TopicView.new(topic.id, user, post_number: post.post_number)
    end

    before do
      Topic.reset_highest(topic.id)
      TopicView.stubs(:chunk_size).returns(3)
    end

    it "snaps to the lower boundary" do
      near_view = topic_view_near(post)
      expect(near_view.desired_post.id).to eq(post.id)
      expect(near_view.posts.map(&:id)).to eq([post.id, answer_plus_2_votes.id, answer_plus_1_vote.id])
    end

    it "snaps to the upper boundary" do
      near_view = topic_view_near(answer_minus_2_votes)

      expect(near_view.desired_post.id).to eq(answer_minus_2_votes.id)
      expect(near_view.posts.map(&:id)).to eq([answer_0_votes.id, answer_minus_1_vote.id, answer_minus_2_votes.id])
    end

    it "returns the posts in the middle" do
      near_view = topic_view_near(answer_0_votes)
      expect(near_view.desired_post.id).to eq(answer_0_votes.id)
      expect(near_view.posts.map(&:id)).to eq([answer_plus_1_vote.id, answer_0_votes.id, answer_minus_1_vote.id])
    end

    it "snaps to the lower boundary when deleted post_number is provided" do
      near_view = TopicView.new(topic.id, user, post_number: topic.posts.where("deleted_at IS NOT NULL").pluck_first(:post_number))

      expect(near_view.desired_post.id).to eq(post.id)
      expect(near_view.posts.map(&:id)).to eq([post.id, answer_plus_2_votes.id, answer_plus_1_vote.id])
    end

    it "snaps to the lower boundary when post_number is too large" do
      near_view = TopicView.new(topic.id, user, post_number: 99999999)

      expect(near_view.desired_post.id).to eq(post.id)
      expect(near_view.posts.map(&:id)).to eq([post.id, answer_plus_2_votes.id, answer_plus_1_vote.id])
    end

    it "returns the posts in the middle when sorted by activity" do
      near_view = TopicView.new(topic.id, user, post_number: answer_minus_1_vote.post_number, filter: TopicView::ACTIVITY_FILTER)

      expect(near_view.desired_post.id).to eq(answer_minus_1_vote.id)
      expect(near_view.posts.map(&:id)).to eq([answer_minus_2_votes.id, answer_minus_1_vote.id, answer_0_votes.id])
    end
  end
end
