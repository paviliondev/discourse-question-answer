# frozen_string_literal: true

module QuestionAnswer
  module TopicViewExtension
    def qa_enabled
      Topic.qa_enabled(@topic)
    end
  end
end
