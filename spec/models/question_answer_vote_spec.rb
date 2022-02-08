# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswerVote do
  fab!(:post) { Fabricate(:post, reply_to_post_number: nil, post_number: 2) }
  fab!(:user) { Fabricate(:user) }
  fab!(:tag) { Fabricate(:tag) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
    post.topic.tags << tag
  end

  context 'validations' do
    it 'ensures votes cannot be created when QnA is disabled' do
      SiteSetting.qa_enabled = false

      qa_vote = QuestionAnswerVote.new(post: post, user: user, direction: QuestionAnswerVote.directions[:up])

      expect(qa_vote.valid?).to eq(false)

      expect(qa_vote.errors.full_messages).to contain_exactly(
        I18n.t("post.qa.errors.qa_not_enabled")
      )
    end

    it 'ensures that only posts in reply to other posts cannot be voted on' do
      post.update!(post_number: 2, reply_to_post_number: 1)

      qa_vote = QuestionAnswerVote.new(post: post, user: user, direction: QuestionAnswerVote.directions[:up])

      expect(qa_vote.valid?).to eq(false)

      expect(qa_vote.errors.full_messages).to contain_exactly(
        I18n.t("post.qa.errors.voting_not_permitted")
      )
    end
  end

  describe '#direction' do
    it 'ensures inclusion of values' do
      qa_vote = QuestionAnswerVote.new(post: post, user: user)

      qa_vote.direction = 'up'

      expect(qa_vote.valid?).to eq(true)

      qa_vote.direction = 'down'

      expect(qa_vote.valid?).to eq(true)

      qa_vote.direction = 'somethingelse'

      expect(qa_vote.valid?).to eq(false)
    end
  end
end
