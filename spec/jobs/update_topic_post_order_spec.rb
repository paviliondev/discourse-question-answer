# frozen_string_literal: true

require_relative '../plugin_helper'

describe Jobs::UpdateTopicPostOrder do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post1) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:post2) { Fabricate(:post, topic: topic, post_number: 2) }
  fab!(:post3) { Fabricate(:post, topic: topic, post_number: 3) }
  fab!(:post4) { Fabricate(:post, topic: topic, post_number: 4, reply_to_post_number: 2) }
  fab!(:tag) { Fabricate(:tag, name: 'question') }

  it "when qa is enabled it sets topic post sort order as qa order" do
    topic.tags = [tag]
    topic.save!
    topic.reload

    Jobs::UpdateTopicPostOrder.new.execute(topic_id: topic.id)

    expect(post1.reload.sort_order).to eq(1)
    expect(post2.reload.sort_order).to eq(2)
    expect(post3.reload.sort_order).to eq(4)
    expect(post4.reload.sort_order).to eq(3)
  end

  it "when qa is disabled it sets topic post sort order as post number" do
    Jobs::UpdateTopicPostOrder.new.execute(topic_id: topic.id)

    expect(post1.sort_order).to eq(1)
    expect(post2.sort_order).to eq(2)
    expect(post3.sort_order).to eq(3)
    expect(post4.sort_order).to eq(4)
  end
end
