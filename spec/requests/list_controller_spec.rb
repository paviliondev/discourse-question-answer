# frozen_string_literal: true

require 'rails_helper'

describe ListController do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:qa_topic) { Fabricate(:topic, category: category, subtype: Topic::QA_SUBTYPE) }
  fab!(:qa_topic_post) { Fabricate(:post, topic: qa_topic) }
  fab!(:qa_topic_answer) { create_post(topic: qa_topic, reply_to_post: nil) }
  fab!(:topic) { Fabricate(:topic) }

  before do
    SiteSetting.qa_enabled = true
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

    expect(qa["is_qa"]).to eq(true)
    expect(non_qa["is_qa"]).to eq(nil)
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

    expect(qa["is_qa"]).to eq(nil)
    expect(non_qa["is_qa"]).to eq(nil)
  end
end
