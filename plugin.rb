# frozen_string_literal: true

# name: discourse-question-answer
# about: Question / Answer Style Topics
# version: 1.6.0
# authors: Angus McLeod, Muhlis Cahyono (muhlisbc@gmail.com)
# url: https://github.com/paviliondev/discourse-question-answer
# transpile_js: true

%i[common desktop mobile].each do |type|
  register_asset "stylesheets/#{type}/question-answer.scss", type
end

enabled_site_setting :qa_enabled

after_initialize do
  %w(
    ../lib/question_answer/engine.rb
    ../lib/question_answer/vote_manager.rb
    ../lib/question_answer/guardian.rb
    ../extensions/category_extension.rb
    ../extensions/post_extension.rb
    ../extensions/post_serializer_extension.rb
    ../extensions/topic_extension.rb
    ../extensions/topic_list_item_serializer_extension.rb
    ../extensions/topic_view_serializer_extension.rb
    ../extensions/topic_view_extension.rb
    ../extensions/user_extension.rb
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

  %w[
    qa_enabled
    qa_disable_like_on_answers
    qa_disable_like_on_questions
    qa_disable_like_on_comments
  ].each do |key|
    Category.register_custom_field_type(key, :boolean)
    add_to_serializer(:basic_category, key.to_sym) { object.send(key) }

    if Site.respond_to?(:preloaded_category_custom_fields)
      Site.preloaded_category_custom_fields << key
    end
  end

  class ::PostSerializer
    include QuestionAnswer::PostSerializerExtension
  end

  register_post_custom_field_type('vote_history', :json)
  register_post_custom_field_type('vote_count', :integer)

  class ::Post
    include QuestionAnswer::PostExtension
  end

  class ::Topic
    include QuestionAnswer::TopicExtension
  end

  class ::TopicView
    include QuestionAnswer::TopicViewExtension
  end

  class ::TopicViewSerializer
    include QuestionAnswer::TopicViewSerializerExtension
  end

  class ::TopicListItemSerializer
    include QuestionAnswer::TopicListItemSerializerExtension
  end

  class ::Category
    include QuestionAnswer::CategoryExtension
  end

  class ::User
    include QuestionAnswer::UserExtension
  end

  class ::Guardian
    include QuestionAnswer::Guardian
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

  add_to_class(:topic_view, :qa_enabled) do
    return @qa_enabled if defined?(@qa_enabled)

    @qa_enabled = @topic.qa_enabled
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
        .group(:post_id, :created_at)
        .pluck(:post_id, :created_at)
    end
  end

  TopicView.apply_custom_default_scope do |scope, topic_view|
    if topic_view.topic.qa_enabled &&
      !topic_view.instance_variable_get(:@replies_to_post_number) &&
      !topic_view.instance_variable_get(:@post_ids)

      scope
        .unscope(:order)
        .where(
          reply_to_post_number: nil,
          post_type: Post.types[:regular]
        )
        .order("CASE post_number WHEN 1 THEN 0 ELSE 1 END, qa_vote_count DESC, post_number ASC")
    else
      scope
    end
  end

  TopicList.on_preload do |topics|
    Category.preload_custom_fields(topics.map(&:category).compact, %w[
      qa_enabled
      qa_disable_like_on_answers
      qa_disable_like_on_questions
      qa_disable_like_on_comments
    ])
  end

  TopicView.on_preload do |topic_view|
    next if !topic_view.qa_enabled

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
        ORDER BY qa_comments.id ASC
        LIMIT #{TopicView::PRELOAD_COMMENTS_COUNT}
      ) X
      WHERE X.id = question_answer_comments.id
    ) Y ON true
    WHERE question_answer_comments.post_id IN (#{post_ids_sql})
    SQL

    QuestionAnswerComment.includes(:user).where("id IN (#{comment_ids_sql})").order(id: :asc).each do |qa_comment|
      topic_view.comments[qa_comment.post_id] ||= []
      topic_view.comments[qa_comment.post_id] << qa_comment
    end

    topic_view.comments_counts = QuestionAnswerComment.where(post_id: post_ids).group(:post_id).count

    topic_view.posts_user_voted = {}

    if topic_view.guardian.user
      QuestionAnswerVote
        .where(user: topic_view.guardian.user, post_id: post_ids)
        .pluck(:post_id, :direction)
        .each do |post_id, direction|

        topic_view.posts_user_voted[post_id] = direction
      end
    end

    topic_view.posts_voted_on =
      QuestionAnswerVote.where(post_id: post_ids).distinct.pluck(:post_id)
  end

  SiteSetting.enable_filtered_replies_view = true
end
