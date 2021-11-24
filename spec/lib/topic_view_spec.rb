# frozen_string_literal: true

require 'rails_helper'

describe TopicView do
  fab!(:tag) { Fabricate(:tag) }
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic).tap { |t| t.tags << tag } }
  fab!(:post) { create_post(topic: topic) }

  fab!(:answer) { create_post(topic: topic) }
  fab!(:comment) { create_post(topic: topic, reply_to_post_number: answer.post_number) }
  fab!(:comment_2) { create_post(topic: topic, reply_to_post_number: answer.post_number) }
  fab!(:comment_3) { create_post(topic: topic, reply_to_post_number: 1) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = "#{tag.name}"
  end

  it "should preload comments and comments count correctly" do
    topic_view = TopicView.new(topic, user)

    expect(topic_view.comments[answer.post_number].map(&:id))
      .to contain_exactly(comment.id, comment_2.id)

    expect(topic_view.comments[1].map(&:id))
      .to contain_exactly(comment_3.id)

    expect(topic_view.comments_counts[answer.id]).to eq(2)
    expect(topic_view.comments_counts[post.id]).to eq(1)
  end
end
