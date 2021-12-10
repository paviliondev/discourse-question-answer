# frozen_string_literal: true

module QuestionAnswer
  module PostSerializerExtension
    def self.included(base)
      base.attributes(
        :qa_vote_count,
        :qa_enabled,
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
      qa_enabled
    end

    def comments
      (@topic_view.comments[object.post_number] || []).map do |post|
        QuestionAnswer::CommentSerializer.new(post, scope: scope, root: false).as_json
      end
    end

    def include_comments?
      @topic_view && qa_enabled
    end

    def comments_count
      @topic_view.comments_counts&.dig(object.id) || 0
    end

    def include_comments_count?
      @topic_view && qa_enabled
    end

    def qa_user_voted_direction
      @topic_view.posts_user_voted[object.id]
    end

    def include_qa_user_voted_direction?
      @topic_view && qa_enabled && @topic_view.posts_user_voted.present?
    end

    def qa_has_votes
      @topic_view.posts_voted_on.include?(object.id)
    end

    def include_qa_has_votes?
      @topic_view && qa_enabled
    end

    def qa_disable_like
      return true if SiteSetting.qa_disable_like_on_answers
      return !!category.qa_disable_like_on_questions if object.post_number == 1
      return !!category.qa_disable_like_on_comments if object.reply_to_post_number
      retrun !!category.qa_disable_like_on_answers
    end

    alias_method :include_qa_disable_like?, :include_comments?

    def qa_enabled
      @topic_view ? @topic_view.qa_enabled : object.qa_enabled
    end

    private

    def topic
      @topic_view ? @topic_view.topic : object.topic
    end

    def category
      topic.category
    end
  end
end
