# frozen_string_literal: true

module QuestionAnswer
  module TopicListItemSerializerExtension
    # For Q&A topics, we always want to link to the first post because timeline
    # ordering is not consistent with last unread.
    def last_read_post_number
      return nil if object.is_qa?
      super
    end

    def include_last_read_post_number?
      if object.is_qa?
        true
      else
        super
      end
    end
  end
end
