# frozen_string_literal: true

module QuestionAnswer
  module TopicListItemSerializerExtension
    def self.included(base)
      base.attributes :is_qa
    end

    def is_qa
      object.is_qa?
    end

    def include_is_qa?
      object.is_qa?
    end
  end
end
