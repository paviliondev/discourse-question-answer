# frozen_string_literal: true

require 'rails_helper'

Fabricator(:comment, from: :post) do
  reply_to_post_number
end

describe Topic do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }

  fab!(:answers) do
    5.times.map { Fabricate(:post, topic: topic) }.sort_by(&:created_at)
  end

  fab!(:comments) do
    5.times.map do
      Fabricate(
        :comment,
        topic: topic,
        reply_to_post_number: 2
      )
    end.sort_by(&:created_at)
  end

  fab!(:tag) { Fabricate(:tag) }

  before do
    SiteSetting.qa_tags = tag.name
    topic.tags << tag
  end

  let(:up) { QuestionAnswerVote.directions[:up] }

  it 'should return correct comments' do
    comment_ids = comments.map(&:id)
    topic_comment_ids = topic.comments.pluck(:id)

    expect(comment_ids).to eq(topic_comment_ids)
  end

  it 'should return correct answers' do
    answer_ids = answers.map(&:id)
    topic_answer_ids = topic.answers.pluck(:id)

    expect(answer_ids).to eq(topic_answer_ids)
  end

  it 'should return correct answer_count' do
    expect(topic.answers.size).to eq(answers.size)
  end

  it 'should return correct last_answered_at' do
    expected = answers.last.created_at

    expect(topic.last_answered_at).to eq_time(expected)
  end

  it 'should return correct last_commented_on' do
    expected = comments.last.created_at

    expect(topic.last_commented_on).to eq(expected)
  end

  it 'should return correct last_answer_post_number' do
    expected = answers.last.post_number

    expect(topic.last_answer_post_number).to eq(expected)
  end

  it 'should return correct last_answerer' do
    expected = answers.last.user.id

    expect(topic.last_answerer.id).to eq(expected)
  end

  describe '.qa_can_vote' do
    it 'should return false if user is blank' do
      expect(Topic.qa_can_vote(topic, nil)).to eq(false)
    end

    it 'should return false if SiteSetting is disabled' do
      SiteSetting.qa_enabled = false

      expect(Topic.qa_can_vote(topic, user)).to eq(false)
    end

    it 'return false if user has voted and qa_trust_level_vote_limits is false' do
      SiteSetting.qa_trust_level_vote_limits = false
      SiteSetting.send("qa_tl#{user.trust_level}_vote_limit=", 10)

      post = answers.first

      QuestionAnswer::VoteManager.vote(post, user, direction: up)

      expect(Topic.qa_can_vote(topic, user)).to eq(false)

      SiteSetting.qa_trust_level_vote_limits = true

      expect(Topic.qa_can_vote(topic, user)).to eq(true)
    end

    it 'return false if trust level zero' do
      expect(Topic.qa_can_vote(topic, user)).to eq(true)

      user.update!(trust_level: 0)

      expect(Topic.qa_can_vote(topic, user)).to eq(false)
    end

    it 'return false if has voted more than qa_tl*_vote_limit' do
      SiteSetting.qa_trust_level_vote_limits = true

      expect(Topic.qa_can_vote(topic, user)).to eq(true)

      SiteSetting.send("qa_tl#{user.trust_level}_vote_limit=", 1)

      QuestionAnswer::VoteManager.vote(answers[0], user, direction: up)

      expect(Topic.qa_can_vote(topic, user)).to eq(false)

      SiteSetting.send("qa_tl#{user.trust_level}_vote_limit=", 2)

      expect(Topic.qa_can_vote(topic, user)).to eq(true)
    end
  end

  describe '.qa_votes' do
    it 'should return nil if user is blank' do
      expect(Topic.qa_votes(topic, nil)).to eq(nil)
    end

    it 'should return nil if disabled' do
      SiteSetting.qa_enabled = false

      expect(Topic.qa_votes(topic, user)).to eq(nil)
    end

    it 'should return voted post IDs' do
      expected = answers.first(3).map do |a|
        QuestionAnswer::VoteManager.vote(a, user, direction: up)

        a.id
      end.sort

      expect(Topic.qa_votes(topic, user).pluck(:post_id))
        .to contain_exactly(*expected)
    end
  end

  describe '.qa_enabled' do
    it 'should return false if topic is blank' do
      expect(Topic.qa_enabled(nil)).to eq(false)
    end

    it 'should return false for a PM' do
      expect(Topic.qa_enabled(Fabricate(:private_message_topic))).to eq(false)
    end

    it 'should return false if disabled' do
      SiteSetting.qa_enabled = false

      expect(Topic.qa_enabled(topic)).to eq(false)
    end

    it 'should return false if category topic' do
      category.update!(topic_id: topic.id)

      expect(Topic.qa_enabled(topic)).to eq(false)
    end

    it 'should return true if has blacklist tags' do
      tags = 3.times.map { Fabricate(:tag) }

      SiteSetting.qa_blacklist_tags = tags.first.name
      SiteSetting.qa_tags = tags.map(&:name).join('|')

      topic.tags = tags

      expect(Topic.qa_enabled(topic)).to eq(false)
    end

    it 'should return true on enabled category' do
      category.custom_fields['qa_enabled'] = true
      category.save!
      category.reload

      expect(Topic.qa_enabled(topic)).to eq(true)
    end

    it 'should return true if question subtype' do
      topic.subtype = 'question'
      topic.save!
      topic.reload

      expect(Topic.qa_enabled(topic)).to eq(true)
    end
  end
end
