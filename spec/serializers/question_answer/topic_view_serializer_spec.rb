# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::TopicViewSerializerExtension do
  fab!(:tag) { Fabricate(:tag) }

  fab!(:topic) do
    Fabricate(:topic).tap do |t|
      t.tags << tag
    end
  end

  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic, reply_to_post_number: nil) }
  let(:comment) { Fabricate(:qa_comment, post: answer) }
  fab!(:user) { Fabricate(:user) }
  fab!(:guardian) { Guardian.new(user) }
  let(:topic_view) { TopicView.new(topic, user) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
    comment
  end

  it 'should return correct values' do
    QuestionAnswer::VoteManager.vote(topic_post, user)
    QuestionAnswer::VoteManager.vote(answer, user)
    QuestionAnswer::VoteManager.vote(answer, Fabricate(:user))
    QuestionAnswer::VoteManager.vote(comment, user)

    payload = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

    expect(payload[:qa_enabled]).to eq(true)
    expect(payload[:last_answered_at]).to eq(answer.created_at)
    expect(payload[:last_commented_on]).to eq(comment.created_at)
    expect(payload[:answer_count]).to eq(1)
    expect(payload[:last_answer_post_number]).to eq(answer.post_number)
    expect(payload[:last_answerer][:id]).to eq(answer.user.id)

    posts = payload[:post_stream][:posts]

    expect(posts.first[:id]).to eq(topic_post.id)
    expect(posts.first[:qa_user_voted_direction]).to eq(QuestionAnswerVote.directions[:up])
    expect(posts.first[:qa_has_votes]).to eq(true)
    expect(posts.first[:qa_vote_count]).to eq(1)
    expect(posts.first[:comments]).to eq([])
    expect(posts.first[:comments_count]).to eq(0)

    expect(posts.last[:id]).to eq(answer.id)
    expect(posts.last[:qa_user_voted_direction]).to eq(QuestionAnswerVote.directions[:up])
    expect(posts.last[:qa_has_votes]).to eq(true)
    expect(posts.last[:qa_vote_count]).to eq(2)
    expect(posts.last[:comments].map { |c| c[:id] }).to contain_exactly(comment.id)
    expect(posts.last[:comments].first[:user_voted]).to eq(true)
    expect(posts.last[:comments_count]).to eq(1)
  end

  it 'should not include dependent_attrs when plugin is disabled' do
    SiteSetting.qa_enabled = false

    payload = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

    expect(payload[:qa_enabled]).to eq(nil)
    expect(payload[:last_answered_at]).to eq(nil)
    expect(payload[:last_commented_on]).to eq(nil)
    expect(payload[:answer_count]).to eq(nil)
    expect(payload[:last_answer_post_number]).to eq(nil)
    expect(payload[:last_answerer]).to eq(nil)
  end
end
