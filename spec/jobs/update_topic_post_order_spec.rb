# frozen_string_literal: true

require_relative '../plugin_helper'

describe Jobs::UpdateTopicPostOrder do
  let (:topic) { Fabricate(:topic) }
  let (:post1) { Fabricate(:post, topic_id: topic.id, post_number: 1) }
  let (:post2) { Fabricate(:post, topic_id: topic.id, post_number: 2) }
  let (:post3) { Fabricate(:post, topic_id: topic.id, post_number: 3) }
  let (:post4) { Fabricate(:post, topic_id: topic.id, post_number: 4, reply_to_post_number: 2) }
  
  it "when qa is enabled it sets topic post sort order as qa order" do
    topic.tags = ['question']
    topic.save
    
    Jobs::UpdateTopicPostOrder.new.execute(topic_id: topic.id)

    expect(post1.sort_order).to eq(1)
    expect(post2.sort_order).to eq(2)
    expect(post3.sort_order).to eq(4)
    expect(post4.sort_order).to eq(3)
  end
  
  it "when qa is disabled it sets topic post sort order as post number" do
    Jobs::UpdateTopicPostOrder.new.execute(topic_id: topic.id)

    expect(post1.sort_order).to eq(1)
    expect(post2.sort_order).to eq(2)
    expect(post3.sort_order).to eq(3)
    expect(post4.sort_order).to eq(4)
  end
end