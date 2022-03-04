# frozen_string_literal: true

module QuestionAnswer
  module TopicViewExtension
    def self.included(base)
      base.attr_accessor(
        :comments,
        :comments_counts,
        :posts_user_voted,
        :comments_user_voted,
        :posts_voted_on
      )

      unless base.const_defined?(:PRELOAD_COMMENTS_COUNT)
        base.const_set :PRELOAD_COMMENTS_COUNT, 5
      end

      if !base.const_defined?(:ACTIVITY_FILTER)
        # Change ORDER_BY_ACTIVITY_FILTER on the client side when the value here is changed
        base.const_set :ACTIVITY_FILTER, "activity"
      end
    end
  end
end
