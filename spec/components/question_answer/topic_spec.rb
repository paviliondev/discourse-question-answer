# frozen_string_literal: true

require 'rails_helper'

describe Topic do
  fab!(:user)  { Fabricate(:user) }
  fab!(:post)  { Fabricate(:post_with_long_raw_content) }

  it 'should update topic sort order correctly' do

  end

  it 'should return the current vote count for the topic' do
    topic = post.topic
    puts topic.qa_votes
    #topic.qa_votes
  end

  it 'should return the correct answer count for the topic' do

  end

  it 'should return the correct comment count for the topic' do

  end

  it 'should return the correct qa enabled value for the topic' do

  end
end