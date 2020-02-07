# frozen_string_literal: true

module QuestionAnswer
  module TopicListItemSerializerExtension
    def self.included(base)
      base.attributes :qa_enabled,
                      :answer_count
    end

    def qa_enabled
      true
    end

    def include_qa_enabled?
      Topic.qa_enabled object
    end

    def answer_count
      object.answer_count
    end

    def include_answer_count?
      include_qa_enabled?
    end
  end
end
