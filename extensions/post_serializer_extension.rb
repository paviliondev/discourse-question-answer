# frozen_string_literal: true

module QuestionAnswer
  module PostSerializerExtension
    def actions_summary
      summaries = super.reject { |s| s[:id] == PostActionType.types[:vote] }

      return summaries unless self.qa_enabled

      user = scope.current_user
      summary = {
        id: PostActionType.types[:vote],
        count: object.qa_vote_count
      }

      if user
        voted =
          if @topic_view
            @topic_view.user_voted_posts(user).include?(object.id)
          else
            QuestionAnswerVote.exists?(post_id: object.id, user_id: user.id)
          end

        if voted
          summary[:acted] = true
          summary[:can_undo] = QuestionAnswer::Vote.can_undo(object, user)
        else
          summary[:can_act] = true
        end
      end

      summary.delete(:count) if summary[:count].zero?

      if summary[:can_act] || summary[:count]
        summaries + [summary]
      else
        summaries
      end
    end

    def comments
      (@topic_view.comments[object.post_number] || []).map do |post|
        QaCommentPostSerializer.new(post, scope: scope, root:false).as_json
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
