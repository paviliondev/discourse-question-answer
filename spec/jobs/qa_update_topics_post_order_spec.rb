# frozen_string_literal: true

require_relative '../plugin_helper'

Fabricator(:post_with_sort_order, from: :post) do
  post_number
  sort_order
  reply_to_post_number
end

describe Jobs::QAUpdateTopicsPostOrder do
  let(:create_post) do
    ->(topic, post_number, sort_order, reply_to_post_number = nil) do
      args = {
        topic: topic,
        post_number: post_number,
        sort_order: sort_order,
        reply_to_post_number: reply_to_post_number
      }

      Fabricate(:post_with_sort_order, args)
    end
  end
  fab!(:tag) { Fabricate(:tag, name: 'question') }
  fab!(:qa_topic) { Fabricate(:topic, tags: [tag]) }
  fab!(:messed_topic) { Fabricate(:topic) }

  it 'should fix post order correctly' do
    expect(qa_topic.qa_enabled).to eq(true)
    qa_post_1 = create_post.call(qa_topic, 1, 5)
    qa_post_2 = create_post.call(qa_topic, 2, 4, 5)
    qa_post_3 = create_post.call(qa_topic, 3, 3, 4)
    qa_post_4 = create_post.call(qa_topic, 4, 2)
    qa_post_5 = create_post.call(qa_topic, 5, 1)

    messed_post_1 = create_post.call(messed_topic, 1, 5)
    messed_post_2 = create_post.call(messed_topic, 2, 4)
    messed_post_3 = create_post.call(messed_topic, 3, 3)
    messed_post_4 = create_post.call(messed_topic, 4, 2)
    messed_post_5 = create_post.call(messed_topic, 5, 1)

    Jobs::QaUpdateTopicsPostOrder.new.execute_onceoff({})

    expect(qa_post_1.reload.sort_order).to eq(1)
    expect(qa_post_2.reload.sort_order).to eq(5)
    expect(qa_post_3.reload.sort_order).to eq(3)
    expect(qa_post_4.reload.sort_order).to eq(2)
    expect(qa_post_5.reload.sort_order).to eq(4)

    expect(messed_post_1.reload.sort_order).to eq(1)
    expect(messed_post_2.reload.sort_order).to eq(2)
    expect(messed_post_3.reload.sort_order).to eq(3)
    expect(messed_post_4.reload.sort_order).to eq(4)
    expect(messed_post_5.reload.sort_order).to eq(5)
  end
end
