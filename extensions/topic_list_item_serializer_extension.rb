# frozen_string_literal: true

module QuestionAnswer
  module TopicListItemSerializerExtension
    # For Q&A topics, we always want to link to the first post because timeline
    # ordering is not consistent with last unread.
    def last_read_post_number
      return nil if qa_enabled?
      super
    end

    def include_last_read_post_number?
      if qa_enabled?
        true
      else
        super
      end
    end

    private

    def qa_enabled?
      @qa_enabled ||= object.qa_enabled
    end
  end
end
