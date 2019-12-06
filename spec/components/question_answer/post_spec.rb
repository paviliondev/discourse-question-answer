# frozen_string_literal: true

require 'rails_helper'

describe Post do
  fab!(:user1)  { Fabricate(:user) }
  fab!(:user2)  { Fabricate(:user) }
  fab!(:post)  { Fabricate(:post_with_long_raw_content) }

  it 'should return the post vote count correctly' do
    QuestionAnswer::Vote.vote(post, user1, {direction: 'up', action: 'create'})
    expect(post.custom_fields['vote_count']).to eq(1)
  end

  it 'should return the post voters correctly' do
    QuestionAnswer::Vote.vote(post, user1, {direction: 'up', action: 'create'})
    expect(post.custom_fields['voted'][0].to_i).to eq(user1.id)
  end

  it 'should return the post vote history correctly' do
    QuestionAnswer::Vote.vote(post, user1, {direction: 'up', action: 'create'})
    history = post.custom_fields['vote_history']
    expect(history[0]['direction']).to eq('up')
    expect(history[0]['action']).to eq('create')
    expect(history[0]['user_id']).to eq(user1.id)
  end

  it 'should return the last voter correctly' do
    QuestionAnswer::Vote.vote(post, user1, {direction: 'up', action: 'create'})
    QuestionAnswer::Vote.vote(post, user2, {direction: 'up', action: 'create'})
    expect(post.custom_fields['voted'].last.to_i).to eq(user2.id)
  end
end