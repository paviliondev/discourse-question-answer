# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::PostExtension do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post_with_long_raw_content) }
  let(:up) { QuestionAnswer::Vote::UP }
  let(:create) { QuestionAnswer::Vote::CREATE }
  let(:destroy) { QuestionAnswer::Vote::DESTROY }
  let(:users) { [user1, user2, user3] }
  let(:vote) do
    ->(user) do
      QuestionAnswer::Vote.vote(post, user, { direction: up, action: create })
    end
  end
  let(:undo_vote) do
    ->(user) do
      QuestionAnswer::Vote.vote(post, user, { direction: up, action: destroy })
    end
  end

  it('should ignore vote_count') do
    expect(Post.ignored_columns.include?("vote_count")).to eq(true)
  end

  it('should include qa_update_vote_order method') do
    expect(post.methods.include?(:qa_update_vote_order)).to eq(true)
  end

  it 'should return the post vote count correctly' do
    # no one voted
    expect(post.qa_vote_count).to eq(0)

    users.each do |u|
      vote.call(u)
    end

    expect(post.qa_vote_count).to eq(users.size)

    users.each do |u|
      undo_vote.call(u)
    end

    expect(post.qa_vote_count).to eq(0)
  end

  it 'should return the post voters correctly' do
    users.each do |u|
      expect(post.qa_voted.include?(u.id)).to eq(false)

      vote.call(u)

      expect(post.qa_voted.include?(u.id)).to eq(true)

      undo_vote.call(u)

      expect(post.qa_voted.include?(u.id)).to eq(false)
    end
  end

  it 'should return the post vote history correctly' do
    expect(post.qa_vote_history.blank?).to eq(true)

    users.each_with_index do |u, i|
      vote.call(u)

      expect(post.qa_vote_history[i]['direction']).to eq(up)
      expect(post.qa_vote_history[i]['action']).to eq(create)
      expect(post.qa_vote_history[i]['user_id']).to eq(u.id)
    end

    users.each_with_index do |u, i|
      undo_vote.call(u)

      idx = users.size + i

      expect(post.qa_vote_history[idx]['direction']).to eq(up)
      expect(post.qa_vote_history[idx]['action']).to eq(destroy)
      expect(post.qa_vote_history[idx]['user_id']).to eq(u.id)
    end
  end

  it 'should return last voted correctly' do
    expect(post.qa_last_voted(user1.id)).to be_falsey

    vote.call(user1)

    # set date 1 month ago
    vote_history = post.qa_vote_history
    vote_history[0]['created_at'] = 1.month.ago

    post.custom_fields['vote_history'] = vote_history.as_json
    post.save
    post.reload

    expect(post.qa_last_voted(user1.id) > 1.minute.ago).to eq(false)

    vote.call(user1)

    expect(post.qa_last_voted(user1.id) > 1.minute.ago).to eq(true)
  end

  it 'should return the last voter correctly' do
    expect(post.qa_voted.last.to_i).to_not eq(user3.id)

    users.each do |u|
      vote.call(u)
    end

    expect(post.qa_voted.last.to_i).to eq(user3.id)
  end

  it 'should return qa_can_vote correctly' do
    expect(post.qa_can_vote(user1.id)).to eq(true)

    vote.call(user1)

    expect(post.qa_can_vote(user1.id)).to eq(false)

    SiteSetting.qa_tl_allow_multiple_votes_per_post = true

    expect(post.qa_can_vote(user1.id)).to eq(true)
  end
end
