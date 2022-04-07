# frozen_string_literal: true

# name: discourse-question-answer
# about: Allows a topic to be created in the Q&A format
# version: 0.0.1
# authors: Alan Tan
# url: https://github.com/discourse/discourse-question-answer
# transpile_js: true

%i[common mobile].each do |type|
  register_asset "stylesheets/#{type}/question-answer.scss", type
end

enabled_site_setting :qa_enabled

after_initialize do
  %w(
    ../lib/question_answer/engine.rb
    ../lib/question_answer/vote_manager.rb
    ../lib/question_answer/guardian.rb
    ../lib/question_answer/comment_creator.rb
    ../extensions/post_extension.rb
    ../extensions/post_serializer_extension.rb
    ../extensions/topic_extension.rb
    ../extensions/topic_list_item_serializer_extension.rb
    ../extensions/topic_view_serializer_extension.rb
    ../extensions/topic_view_extension.rb
    ../extensions/user_extension.rb
    ../app/validators/question_answer_comment_validator.rb
    ../app/controllers/question_answer/votes_controller.rb
    ../app/controllers/question_answer/comments_controller.rb
    ../app/models/question_answer_vote.rb
    ../app/models/question_answer_comment.rb
    ../app/serializers/basic_voter_serializer.rb
    ../app/serializers/question_answer_comment_serializer.rb
    ../config/routes.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  if respond_to?(:register_svg_icon)
    register_svg_icon 'angle-up'
    register_svg_icon 'info'
  end

  register_post_custom_field_type('vote_history', :json)
  register_post_custom_field_type('vote_count', :integer)

  reloadable_patch do
    Post.include(QuestionAnswer::PostExtension)
    Topic.include(QuestionAnswer::TopicExtension)
    PostSerializer.include(QuestionAnswer::PostSerializerExtension)
    TopicView.prepend(QuestionAnswer::TopicViewExtension)
    TopicViewSerializer.include(QuestionAnswer::TopicViewSerializerExtension)
    TopicListItemSerializer.include(QuestionAnswer::TopicListItemSerializerExtension)
    User.include(QuestionAnswer::UserExtension)
    Guardian.include(QuestionAnswer::Guardian)
  end

  # TODO: Performance of the query degrades as the number of posts a user has voted
  # on increases. We should probably keep a counter cache in the user's
  # custom fields.
  add_to_class(:user, :vote_count) do
    Post.where(user_id: self.id).sum(:qa_vote_count)
  end

  add_to_serializer(:user_card, :vote_count) do
    object.vote_count
  end

  add_to_class(:topic_view, :user_voted_posts) do |user|
    @user_voted_posts ||= {}

    @user_voted_posts[user.id] ||= begin
      QuestionAnswerVote.where(user: user, post: @posts).distinct.pluck(:post_id)
    end
  end

  add_to_class(:topic_view, :user_voted_posts_last_timestamp) do |user|
    @user_voted_posts_last_timestamp ||= {}

    @user_voted_posts_last_timestamp[user.id] ||= begin
      QuestionAnswerVote
        .where(user: user, post: @posts)
        .group(:votable_id, :created_at)
        .pluck(:votable_id, :created_at)
    end
  end

  TopicView.apply_custom_default_scope do |scope, topic_view|
    if topic_view.topic.is_qa? &&
      !topic_view.instance_variable_get(:@replies_to_post_number) &&
      !topic_view.instance_variable_get(:@post_ids)

      scope = scope.where(
        reply_to_post_number: nil,
        post_type: Post.types[:regular]
      )

      if topic_view.instance_variable_get(:@filter) != TopicView::ACTIVITY_FILTER
        scope = scope
          .unscope(:order)
          .order("CASE post_number WHEN 1 THEN 0 ELSE 1 END, qa_vote_count DESC, post_number ASC")
      end

      scope
    else
      scope
    end
  end

  TopicView.on_preload do |topic_view|
    next if !topic_view.topic.is_qa?

    topic_view.comments = {}

    post_ids = topic_view.posts.pluck(:id)
    post_ids_sql = post_ids.join(",")

    comment_ids_sql = <<~SQL
    SELECT
      question_answer_comments.id
    FROM question_answer_comments
    INNER JOIN LATERAL (
      SELECT 1
      FROM (
        SELECT
          qa_comments.id
        FROM question_answer_comments qa_comments
        WHERE qa_comments.post_id = question_answer_comments.post_id
        AND qa_comments.deleted_at IS NULL
        ORDER BY qa_comments.id ASC
        LIMIT #{TopicView::PRELOAD_COMMENTS_COUNT}
      ) X
      WHERE X.id = question_answer_comments.id
    ) Y ON true
    WHERE question_answer_comments.post_id IN (#{post_ids_sql})
    AND question_answer_comments.deleted_at IS NULL
    SQL

    QuestionAnswerComment.includes(:user).where("id IN (#{comment_ids_sql})").order(id: :asc).each do |qa_comment|
      topic_view.comments[qa_comment.post_id] ||= []
      topic_view.comments[qa_comment.post_id] << qa_comment
    end

    topic_view.comments_counts = QuestionAnswerComment.where(post_id: post_ids).group(:post_id).count

    topic_view.posts_user_voted = {}
    topic_view.comments_user_voted = {}

    if topic_view.guardian.user
      QuestionAnswerVote
        .where(user: topic_view.guardian.user, votable_type: 'Post', votable_id: post_ids)
        .pluck(:votable_id, :direction)
        .each do |post_id, direction|

        topic_view.posts_user_voted[post_id] = direction
      end

      QuestionAnswerVote
        .joins("INNER JOIN question_answer_comments qa_comments ON qa_comments.id = question_answer_votes.votable_id")
        .where(user: topic_view.guardian.user, votable_type: 'QuestionAnswerComment')
        .where("qa_comments.post_id IN (?)", post_ids)
        .pluck(:votable_id)
        .each do |votable_id|

        topic_view.comments_user_voted[votable_id] = true
      end
    end

    topic_view.posts_voted_on =
      QuestionAnswerVote.where(votable_type: 'Post', votable_id: post_ids).distinct.pluck(:votable_id)
  end

  add_permitted_post_create_param(:create_as_qa)

  # TODO: Core should be exposing the following as proper plugin interfaces.
  NewPostManager.add_plugin_payload_attribute(:subtype)
  TopicSubtype.register(Topic::QA_SUBTYPE)

  NewPostManager.add_handler do |manager|
    if !manager.args[:topic_id] &&
      manager.args[:create_as_qa] == 'true' &&
      (manager.args[:archetype].blank? || manager.args[:archetype] == Archetype.default)

      manager.args[:subtype] = Topic::QA_SUBTYPE
    end

    false
  end
end
