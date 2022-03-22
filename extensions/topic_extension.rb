# frozen_string_literal: true

module QuestionAnswer
  module TopicExtension
    def self.included(base)
      base.extend(ClassMethods)
      base.validate :ensure_regular_topic, on: [:create]
      base.validate :ensure_no_qa_subtype, on: [:update]
      base.const_set :QA_SUBTYPE, 'question_answer'
    end

    def reload(options = nil)
      @answers = nil
      @comments = nil
      @last_answerer = nil
      @is_qa = nil
      super(options)
    end

    def answers
      @answers ||= begin
        posts
          .where(reply_to_post_number: nil)
          .where.not(post_number: 1)
          .order(post_number: :asc)
      end
    end

    def answer_count
      answers.count
    end

    def last_answered_at
      return unless answers.present?

      answers.last[:created_at]
    end

    def comments
      @comments ||= begin
        QuestionAnswerComment.joins(:post).where("posts.topic_id = ?", self.id)
      end
    end

    def last_commented_on
      return unless comments.present?

      comments.last.created_at
    end

    def last_answer_post_number
      return unless answers.any?

      answers.last.post_number
    end

    def last_answerer
      return unless answers.any?

      @last_answerer ||= User.find(answers.last[:user_id])
    end

    def is_qa?
      @is_qa ||= SiteSetting.qa_enabled && self.subtype == Topic::QA_SUBTYPE
    end

    # class methods
    module ClassMethods
      # rename to something like qa_user_votes?
      def qa_votes(topic, user)
        return nil if !user || !SiteSetting.qa_enabled

        # This is a very inefficient way since the performance degrades as the
        # number of voted posts in the topic increases.
        QuestionAnswerVote
          .joins("INNER JOIN posts ON posts.id = question_answer_votes.votable_id")
          .where(user: user, votable_type: 'Post')
          .where("posts.topic_id = ?", topic.id)
      end
    end

    private

    def ensure_no_qa_subtype
      if will_save_change_to_subtype? && self.subtype == Topic::QA_SUBTYPE
        self.errors.add(:base, I18n.t("topic.qa.errors.cannot_change_to_qa_subtype"))
      end
    end

    def ensure_regular_topic
      return if self.subtype != Topic::QA_SUBTYPE

      if !SiteSetting.qa_enabled
        self.errors.add(:base, I18n.t("topic.qa.errors.qa_not_enabled"))
      elsif self.archetype != Archetype.default
        self.errors.add(:base, I18n.t("topic.qa.errors.subtype_not_allowed"))
      end
    end
  end
end
