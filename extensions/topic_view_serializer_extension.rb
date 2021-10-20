# frozen_string_literal: true

module QuestionAnswer
  module TopicViewSerializerExtension
    def self.included(base)
      base.attributes(
        :qa_enabled,
        :last_answered_at,
        :last_commented_on,
        :answer_count,
        :comment_count,
        :last_answer_post_number,
        :last_answerer,
        :first_answer_id
      )
    end

    def first_answer_id
      object.topic.first_answer&.id
    end

    def qa_enabled
      object.qa_enabled
    end

    def last_answered_at
      object.topic.last_answered_at
    end

    def include_last_answered_at?
      qa_enabled
    end

    def last_commented_on
      object.topic.last_commented_on
    end

    def include_last_commented_on?
      qa_enabled
    end

    def answer_count
      object.topic.answer_count
    end

    def include_answer_count?
      qa_enabled
    end

    def comment_count
      object.topic.comment_count
    end

    def include_comment_count?
      qa_enabled
    end

    def last_answer_post_number
      object.topic.last_answer_post_number
    end

    def include_last_answer_post_number?
      qa_enabled
    end

    def last_answerer
      BasicUserSerializer.new(
        object.topic.last_answerer,
        scope: scope,
        root: false
      ).as_json
    end

    def include_last_answerer?
      qa_enabled
    end
  end
end
