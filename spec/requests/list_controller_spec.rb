# frozen_string_literal: true

require 'rails_helper'

describe ListController do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:qa_topic) { Fabricate(:topic, category: category) }
  fab!(:qa_topic_post) { Fabricate(:post, topic: qa_topic) }
  fab!(:qa_topic_answer) { create_post(topic: qa_topic, reply_to_post: nil) }
  fab!(:topic) { Fabricate(:topic) }

  before do
    category.custom_fields['qa_enabled'] = true
    category.save_custom_fields
    sign_in(user)
  end

  it 'should return the right attributes for Q&A topics' do
    TopicUser.create!(user: user, topic: qa_topic, last_read_post_number: 2)
    TopicUser.create!(user: user, topic: topic, last_read_post_number: 2)

    get "/latest.json"

    expect(response.status).to eq(200)

    topics = response.parsed_body["topic_list"]["topics"]

    qa = topics.find { |t| t["id"] == qa_topic.id }
    non_qa = topics.find { |t| t["id"] == topic.id }

    expect(qa["last_read_post_number"]).to eq(nil)
    expect(non_qa["last_read_post_number"]).to eq(2)
  end

  it 'should return the right attributes when Q&A is disabled' do
    SiteSetting.qa_enabled = false

    TopicUser.create!(user: user, topic: qa_topic, last_read_post_number: 2)
    TopicUser.create!(user: user, topic: topic, last_read_post_number: 2)

    get "/latest.json"

    expect(response.status).to eq(200)

    topics = response.parsed_body["topic_list"]["topics"]

    qa = topics.find { |t| t["id"] == qa_topic.id }
    non_qa = topics.find { |t| t["id"] == topic.id }

    expect(qa["last_read_post_number"]).to eq(2)
    expect(non_qa["qa_enabled"]).to eq(nil)
  end
end
