# frozen_string_literal: true

require_relative '../../plugin_helper'

describe QuestionAnswer::TopicTagExtension do
  let (:qa_tag) { Fabricate(:tag, name: 'question') }
  let (:non_qa_tag) { Fabricate(:tag, name: 'tag1') }
  
  it 'should call callback correctly' do
    topic_tag = TopicTag.new(tag_id: qa_tag.id)

    expect(topic_tag.qa_tag?).to eq(true)

    topic_tag = TopicTag.new(tag_id: non_qa_tag.id)

    expect(topic_tag.qa_tag?).to eq(false)
  end
end
