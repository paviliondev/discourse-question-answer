# frozen_string_literal: true

require_relative '../../plugin_helper'

describe QuestionAnswer::TopicTagExtension do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:qa_tag) { Fabricate(:tag, name: 'question') }
  fab!(:non_qa_tag) { Fabricate(:tag, name: 'tag1') }
  fab!(:topic_tag_qa) { Fabricate(:topic_tag, tag: qa_tag, topic: topic) }
  fab!(:topic_tag_non_qa) { Fabricate(:topic_tag, tag: non_qa_tag, topic: topic) }

  it 'should call callback correctly' do
    expect(topic_tag_qa.qa_tag?).to eq(true)
    TopicTag.any_instance.expects(:update_post_order).once

    topic_tag_qa.destroy # destroy to test if callback called

    expect(topic_tag_non_qa.qa_tag?).to eq(false)
    TopicTag.any_instance.expects(:update_post_order).never

    topic_tag_non_qa.destroy
  end
end
