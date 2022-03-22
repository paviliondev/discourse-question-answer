# frozen_string_literal: true

module QuestionAnswer
  module PostSerializerExtension
    def self.included(base)
      base.attributes(
        :qa_vote_count,
        :qa_user_voted_direction,
        :qa_has_votes,
        :comments,
        :comments_count,
      )
    end

    def qa_vote_count
      object.qa_vote_count
    end

    def include_qa_vote_count?
      object.is_qa_topic?
    end

    def comments
      (@topic_view.comments[object.id] || []).map do |comment|
        serializer = QuestionAnswerCommentSerializer.new(comment, scope: scope, root: false)
        serializer.comments_user_voted = @topic_view.comments_user_voted
        serializer.as_json
      end
    end

    def include_comments?
      @topic_view && object.is_qa_topic?
    end

    def comments_count
      @topic_view.comments_counts&.dig(object.id) || 0
    end

    def include_comments_count?
      @topic_view && object.is_qa_topic?
    end

    def qa_user_voted_direction
      @topic_view.posts_user_voted[object.id]
    end

    def include_qa_user_voted_direction?
      @topic_view && object.is_qa_topic? && @topic_view.posts_user_voted.present?
    end

    def qa_has_votes
      @topic_view.posts_voted_on.include?(object.id)
    end

    def include_qa_has_votes?
      @topic_view && object.is_qa_topic?
    end

    private

    def topic
      @topic_view ? @topic_view.topic : object.topic
    end
  end
end
