# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::Vote do
  fab!(:user)  { Fabricate(:user) }
  fab!(:post)  { Fabricate(:post_with_long_raw_content) }
  let(:vote_args) { { direction: 'up', action: 'create' } }
  let(:unvote_args) { { direction: 'up', action: 'destroy' } }

  it 'should create a vote' do
    vote = QuestionAnswer::Vote.vote(post, user, vote_args)

    expect(vote).to eq(true)
  end

  it 'should destroy a vote' do
    vote = QuestionAnswer::Vote.vote(post, user, unvote_args)

    expect(vote).to eq(true)
  end

  it 'should increment the vote count on create' do
    expect(post.qa_vote_count).to eq(0)

    QuestionAnswer::Vote.vote(post, user, vote_args)

    expect(post.qa_vote_count).to eq(1)
  end

  it 'should decrement the vote count on destroy' do
    QuestionAnswer::Vote.vote(post, user, vote_args)

    expect(post.qa_vote_count).to eq(1)

    QuestionAnswer::Vote.vote(post, user, unvote_args)

    expect(post.qa_vote_count).to eq(0)
  end

  it 'should save vote changes to vote history' do
    QuestionAnswer::Vote.vote(post, user, vote_args)

    vote_history = post.qa_vote_history

    expect(vote_history[0]['direction']).to eq('up')
    expect(vote_history[0]['action']).to eq('create')
    expect(vote_history[0]['user_id']).to eq(user.id)
  end

  it 'should return the correct undo window' do
    expect(SiteSetting.qa_undo_vote_action_window.to_i).to eq(10)
  end
end
