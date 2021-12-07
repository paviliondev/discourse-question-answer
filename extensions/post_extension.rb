# frozen_string_literal: true

module QuestionAnswer
  module PostExtension
    def self.included(base)
      base.ignored_columns = %w[vote_count]

      base.has_many :question_answer_votes

      base.validate :ensure_valid_qa_comment
    end

    def qa_enabled
      ::Topic.qa_enabled(topic)
    end

    def qa_last_voted(user_id)
      QuestionAnswerVote
        .where(post_id: self.id, user_id: user_id)
        .order(created_at: :desc)
        .pluck_first(:created_at)
    end

    def qa_can_vote(user_id)
      !QuestionAnswerVote.exists?(post_id: self.id, user_id: user_id)
    end

    def comments
      topic
        .posts
        .where(reply_to_post_number: self.post_number)
        .order('post_number ASC')
    end

    private

    def ensure_valid_qa_comment
      if will_save_change_to_reply_to_post_number? &&
          reply_to_post_number &&
          !Post.exists?(topic_id: topic_id, reply_to_post_number: nil, post_number: reply_to_post_number) &&
          qa_enabled

        errors.add(:base, I18n.t("post.qa.errors.depth"))
      end
    end
  end
end
