# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::TopicViewSerializerExtension do
  fab!(:category) do
    Fabricate(:category).tap do |c|
      c.custom_fields["qa_enabled"] = true
      c.save!
    end
  end

  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic, reply_to_post_number: nil) }
  let(:comment) { Fabricate(:qa_comment, post: answer) }
  fab!(:user) { Fabricate(:user) }
  fab!(:guardian) { Guardian.new(user) }
  let(:topic_view) { TopicView.new(topic, user) }

  before do
    SiteSetting.qa_enabled = true
    comment
  end

  it 'should return correct values' do
    payload = TopicViewSerializer.new(topic_view, scope: guardian, root: false).as_json

    expect(payload[:qa_enabled]).to eq(true)
    expect(payload[:last_answered_at]).to eq(answer.created_at)
    expect(payload[:last_commented_on]).to eq(comment.created_at)
    expect(payload[:answer_count]).to eq(1)
    expect(payload[:last_answer_post_number]).to eq(answer.post_number)
    expect(payload[:last_answerer][:id]).to eq(answer.user.id)
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
