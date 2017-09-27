# name: discourse-question-answer
# about: QnA Style Topics
# version: 0.1
# authors: Angus McLeod

register_asset 'stylesheets/qa-styles.scss'

after_initialize do
  Category.register_custom_field_type('qa_enabled', :boolean)
  add_to_serializer(:basic_category, :qa_enabled) { object.custom_fields["qa_enabled"] }

  module QAHelper
    class << self
      def qa_enabled(topic)
        tags = topic.tags.map(&:name)
        has_qa_tag = !(tags & SiteSetting.qa_tags.split('|')).empty?
        is_qa_category = topic.category && topic.category.custom_fields["qa_enabled"]
        is_qa_subtype = topic.subtype == 'question'
        has_qa_tag || is_qa_category || is_qa_subtype
      end

      ## This should be replaced with a :voted? property in TopicUser - but how to do this properly in a plugin?
      def user_has_voted(topic, user)
        return nil if !user

        PostAction.exists?(post_id: topic.posts.map(&:id),
                           user_id: user.id,
                           post_action_type_id: PostActionType.types[:vote])
      end

      def update_order(topic_id)

        posts = Post.where(topic_id: topic_id)

        # All answers ordered by vote count then by post number
        answers = posts.where(reply_to_post_number: [nil, ''])
          .where.not(post_number: 1)
          .order("vote_count DESC, post_number ASC")

        # Counting mechanism assumes there won't be more than 5000 posts in total in the topic
        count = 5000
        answers.each do |a|
          votes = a.vote_count
          a.update(sort_order: votes + count)
          count -= 1

          # Replying to posts that are themselves replies to posts is disabled, so there are no comments on comments
          comments = posts.where(reply_to_post_number: a.post_number)
            .order("post_number ASC")
          comments.each do |c|
            c.update(sort_order: votes + count)
            count -= 1
          end
        end
      end
    end
  end

  ::PostSerializer.class_eval do
    attributes :vote_count
  end

  require 'post_actions_controller'
  class ::PostActionsController
    before_action :check_if_voted, only: :create

    def check_if_voted
      if current_user && params[:post_action_type_id].to_i === PostActionType.types[:vote] &&
        QAHelper.qa_enabled(@post.topic) && QAHelper.user_has_voted(@post.topic, current_user)
        raise Discourse::InvalidAccess.new, I18n.t('vote.alread_voted')
      end
    end
  end

  class ::Post
    after_create :update_qa_order

    def update_qa_order
      QAHelper.update_order(topic_id)
    end
  end

  class ::PostAction
    after_commit :update_qa_order, if: :is_vote?

    def is_vote?
      post_action_type_id == PostActionType.types[:vote]
    end

    def notify_subscribers
      if (is_like? || is_flag? || is_vote?) && post
        post.publish_change_to_clients! :acted
      end
    end

    def update_qa_order
      topic_id = Post.where(id: post_id).pluck(:topic_id).first
      QAHelper.update_order(topic_id)
    end
  end

  TopicView.class_eval do
    def qa_enabled
      QAHelper.qa_enabled(@topic)
    end

    def filter_posts_by_ids(post_ids)
      if qa_enabled

        # All Posts
        posts = Post.where(id: post_ids, topic_id: @topic.id)
          .includes(:user, :reply_to_user, :incoming_email)

        # First post should always be first. Sort_order is set after_commit in post action and after_create in post
        @posts = posts.order("case when post_number = 1 then 0 else 1 end, sort_order DESC")

        @posts = filter_post_types(@posts)
        @posts = @posts.with_deleted if @guardian.can_see_deleted_posts?
        @posts
      else
        super
      end
    end
  end

  require 'topic_view_serializer'
  class ::TopicViewSerializer
    attributes :voted, :qa_enabled

    def qa_enabled
      QAHelper.qa_enabled(object.topic)
    end

    def voted
      scope.current_user && QAHelper.user_has_voted(object.topic, scope.current_user)
    end
  end
end
