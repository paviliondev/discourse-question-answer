# frozen_string_literal: true

module QuestionAnswer
  module TopicViewExtension
    def qa_enabled
      Topic.qa_enabled(@topic)
    end

    def filter_posts_by_ids(post_ids)
      if qa_enabled
        posts = begin
          Post
            .where(id: post_ids, topic_id: @topic.id)
            .includes(:user, :reply_to_user, :incoming_email)
        end
        order = 'case when post_number = 1 then 0 else 1 end, sort_order ASC'
        @posts = posts.order(order)
        @posts = filter_post_types(@posts)
        @posts = @posts.with_deleted if @guardian.can_see_deleted_posts?

        @posts
      else
        super
      end
    end
  end
end
