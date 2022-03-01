# frozen_string_literal: true

require 'rails_helper'

describe TopicView do
  fab!(:tag) { Fabricate(:tag) }
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic).tap { |t| t.tags << tag } }
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
    SiteSetting.qa_tags = tag.name
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
end
