# name: discourse-qa
# about: QnA Style Topics
# version: 0.1
# authors: Angus McLeod

register_asset 'stylesheets/qa-styles.scss', :desktop

after_initialize do
  Category.register_custom_field_type('qa_enabled', :boolean)

  module QAHelper
    class << self
      def qa_enabled(topic)
        tags = topic.tags.map(&:name)
        has_qa_tag = !(tags & SiteSetting.qa_tags.split('|')).empty?
        is_qa_category = topic.category && topic.category.custom_fields["qa_enabled"]
        is_qa_subtype = topic.subtype == 'question'
        has_qa_tag || is_qa_category || is_qa_subtype
      end

      ## This should be replaced with a :voted? property in TopicUser - but how to do this in a plugin?
      def user_has_voted(topic, user)
        return nil if !user

        PostAction.exists?(post_id: topic.posts.map(&:id),
                           user_id: user.id,
                           post_action_type_id: PostActionType.types[:vote])
      end
    end
  end

  require 'post_serializer'
  class ::PostSerializer
    attributes :vote_count, :sort_order
  end

  require 'post_actions_controller'
  class ::PostActionsController
    before_filter :check_if_voted, only: :create

    def check_if_voted
      if current_user && QAHelper.qa_enabled(@post.topic)
        if QAHelper.user_has_voted(@post.topic, current_user)
          raise Discourse::InvalidAccess.new, I18n.t('vote.alread_voted')
        end
      end
    end
  end

  require 'post_action'
  class ::PostAction
    def is_vote?
      post_action_type_id == PostActionType.types[:vote]
    end

    def notify_subscribers
      if (is_like? || is_flag? || is_vote?) && post
        post.publish_change_to_clients! :acted
      end
    end
  end

  DiscourseEvent.on(:post_created) do |post, opts, user|
    if !post.is_first_post? && QAHelper.qa_enabled(post.topic) && post.post_type == 1
      post.sort_order = Topic.max_sort_order
      post.save!
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

  add_to_serializer(:basic_category, :qa_enabled) { object.custom_fields["qa_enabled"] }
end
