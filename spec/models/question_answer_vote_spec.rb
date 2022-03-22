# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswerVote do
  fab!(:topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user) { Fabricate(:user) }
  fab!(:tag) { Fabricate(:tag) }

  before do
    SiteSetting.qa_enabled = true
  end

  context 'validations' do
    context 'posts' do
      it 'ensures votes cannot be created when QnA is disabled' do
        SiteSetting.qa_enabled = false

        qa_vote = QuestionAnswerVote.new(votable: post, user: user, direction: QuestionAnswerVote.directions[:up])

        expect(qa_vote.valid?).to eq(false)

        expect(qa_vote.errors.full_messages).to contain_exactly(
          I18n.t("post.qa.errors.qa_not_enabled")
        )
      end

      it 'ensures that only posts in reply to other posts cannot be voted on' do
        post.update!(post_number: 2, reply_to_post_number: 1)

        qa_vote = QuestionAnswerVote.new(votable: post, user: user, direction: QuestionAnswerVote.directions[:up])

        expect(qa_vote.valid?).to eq(false)

        expect(qa_vote.errors.full_messages).to contain_exactly(
          I18n.t("post.qa.errors.voting_not_permitted")
        )
      end

      it 'ensures that votes can only be created for valid polymorphic types' do
        qa_vote = QuestionAnswerVote.new(votable: post.topic, user: user, direction: QuestionAnswerVote.directions[:up])

        expect(qa_vote.valid?).to eq(false)
        expect(qa_vote.errors[:votable_type].present?).to eq(true)
      end
    end

    context 'comments' do
      fab!(:qa_comment) { Fabricate(:qa_comment, post: post) }

      it 'ensures vote cannot be created on a comment when QnA is disabled' do
        SiteSetting.qa_enabled = false
        qa_comment.reload

        qa_vote = QuestionAnswerVote.new(votable: qa_comment, user: user, direction: QuestionAnswerVote.directions[:up])

        expect(qa_vote.valid?).to eq(false)

        expect(qa_vote.errors.full_messages).to contain_exactly(
          I18n.t("post.qa.errors.qa_not_enabled")
        )
      end

      it 'ensures vote cannot be created on a comment when it is a downvote' do
        qa_vote = QuestionAnswerVote.new(votable: qa_comment, user: user, direction: QuestionAnswerVote.directions[:down])

        expect(qa_vote.valid?).to eq(false)

        expect(qa_vote.errors.full_messages).to contain_exactly(
          I18n.t("post.qa.errors.comment_cannot_be_downvoted")
        )
      end
    end
  end

  describe '#direction' do
    it 'ensures inclusion of values' do
      qa_vote = QuestionAnswerVote.new(votable: post, user: user)

      qa_vote.direction = 'up'

      expect(qa_vote.valid?).to eq(true)

      qa_vote.direction = 'down'

      expect(qa_vote.valid?).to eq(true)

      qa_vote.direction = 'somethingelse'

      expect(qa_vote.valid?).to eq(false)
    end
  end
end
