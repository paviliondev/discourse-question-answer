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
        has_qa_tag || is_qa_category
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

  #create qa specific badges
  upvotes_id = BadgeGrouping.find_or_create_by(name: "Upvotes", position: 1).id
  badge_type_gold_id = BadgeType.find_by(name: "Gold").id
  badge_type_silver_id = BadgeType.find_by(name: "Silver").id
  badge_type_bronze_id = BadgeType.find_by(name: "Bronze").id

  professor = {
    name: "Professor",
    description: "Received more than 100 total upvotes",
    badge_type_id: badge_type_gold_id,
    allow_title: true,
    multiple_grant: false,
    icon: "fa-graduation-cap",
    listable: true,
    target_posts: false,
    query:
    "SELECT count(*), r.username Liked, r.id user_id, current_timestamp granted_at\nFROM post_actions pa\nINNER JOIN posts p on p.id=pa.post_id /* Get post details */\nINNER JOIN users r on r.id=p.user_id /* The user who made the post that was liked */\nWHERE pa.post_action_type_id=5 /* upvote type */\nGROUP BY Liked, r.id\nHAVING count(*) >= 100 /* Change to suit */\nORDER BY count(*) DESC",
    enabled: true,
    auto_revoke: false,
    badge_grouping_id: upvotes_id,
    trigger: 0,
    show_posts: false,
    system: false,
    image: "fa-graduation-cap",
    long_description: ""
  }

  teacher = {
    name: "Teacher",
    description: "Received more than 20 total upvotes",
    badge_type_id: badge_type_silver_id,
    allow_title: true,
    multiple_grant: false,
    icon: "fa-graduation-cap",
    listable: true,
    target_posts: false,
    query:
    "SELECT count(*), r.username Liked, r.id user_id, current_timestamp granted_at\nFROM post_actions pa\nINNER JOIN posts p on p.id=pa.post_id /* Get post details */\nINNER JOIN users r on r.id=p.user_id /* The user who made the post that was liked */\nWHERE pa.post_action_type_id=5 /* upvote type */\nGROUP BY Liked, r.id\nHAVING count(*) >= 20 /* Change to suit */\nORDER BY count(*) DESC",
    enabled: true,
    auto_revoke: false,
    badge_grouping_id: upvotes_id,
    trigger: 0,
    show_posts: false,
    system: false,
    image: "fa-graduation-cap",
    long_description: ""
  }

  tutor = {
    name: "Tutor",
    description: "Received more than 10 total upvotes",
    badge_type_id: badge_type_bronze_id,
    allow_title: true,
    multiple_grant: false,
    icon: "fa-graduation-cap",
    listable: true,
    target_posts: false,
    query:
    "SELECT count(*), r.username Liked, r.id user_id, current_timestamp granted_at\nFROM post_actions pa\nINNER JOIN posts p on p.id=pa.post_id /* Get post details */\nINNER JOIN users r on r.id=p.user_id /* The user who made the post that was liked */\nWHERE pa.post_action_type_id=5 /* upvote type */\nGROUP BY Liked, r.id\nHAVING count(*) >= 10 /* Change to suit */\nORDER BY count(*) DESC",
    enabled: true,
    auto_revoke: false,
    badge_grouping_id: upvotes_id,
    trigger: 0,
    show_posts: false,
    system: false,
    image: "fa-graduation-cap",
    long_description: ""
  }

  goal = {
    name: "Goooal!!!",
    description: "Received one upvote for an answer",
    badge_type_id: badge_type_bronze_id,
    allow_title: false,
    multiple_grant: true,
    icon: "fa-futbol-o",
    listable: true,
    target_posts: false,
    query: "SELECT p.user_id, p.id post_id, p.updated_at granted_at\nFROM badge_posts p\nWHERE p.vote_count >= 1 AND\n(:backfill OR p.id IN (:post_ids) )",
    enabled: true,
    auto_revoke: false,
    badge_grouping_id: upvotes_id,
    trigger: 1,
    show_posts: true,
    system: false,
    image: "fa-futbol-o",
    long_description: nil
  }

  double_play = {
    name: "Double Play",
    description: "Received two upvotes for an answer",
    badge_type_id: badge_type_silver_id,
    allow_title: false,
    multiple_grant: true,
    icon: "fa-futbol-o",
    listable: true,
    target_posts: false,
    query: "SELECT p.user_id, p.id post_id, p.updated_at granted_at\nFROM badge_posts p\nWHERE p.vote_count >= 2 AND\n(:backfill OR p.id IN (:post_ids) )",
    enabled: true,
    auto_revoke: false,
    badge_grouping_id: upvotes_id,
    trigger: 1,
    show_posts: true,
    system: false,
    image: "fa-futbol-o",
    long_description: nil
  }

  hat_trick = {
    name: "Hat-trick",
    description: "Received three upvotes for an answer",
    badge_type_id: badge_type_gold_id,
    allow_title: false,
    multiple_grant: true,
    icon: "fa-futbol-o",
    listable: true,
    target_posts: false,
    query: "SELECT p.user_id, p.id post_id, p.updated_at granted_at\nFROM badge_posts p\nWHERE p.vote_count >= 3 AND\n(:backfill OR p.id IN (:post_ids) )",
    enabled: true,
    auto_revoke: false,
    badge_grouping_id: upvotes_id,
    trigger: 1,
    show_posts: true,
    system: false,
    image: "fa-futbol-o",
    long_description: nil
  }

  Badge.find_or_create_by(professor)
  Badge.find_or_create_by(teacher)
  Badge.find_or_create_by(tutor)
  Badge.find_or_create_by(goal)
  Badge.find_or_create_by(double_play)
  Badge.find_or_create_by(hat_trick)
end
