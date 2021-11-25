# frozen_string_literal: true

# name: discourse-question-answer
# about: Question / Answer Style Topics
# version: 1.6.0
# authors: Angus McLeod, Muhlis Cahyono (muhlisbc@gmail.com)
# url: https://github.com/paviliondev/discourse-question-answer

%i[common desktop mobile].each do |type|
  register_asset "stylesheets/#{type}/question-answer.scss", type
end

enabled_site_setting :qa_enabled

after_initialize do
  %w(
    ../lib/question_answer/engine.rb
    ../lib/question_answer/vote_manager.rb
    ../extensions/category_extension.rb
    ../extensions/post_extension.rb
    ../extensions/post_serializer_extension.rb
    ../extensions/topic_extension.rb
    ../extensions/topic_list_item_serializer_extension.rb
    ../extensions/topic_view_serializer_extension.rb
    ../app/controllers/question_answer/votes_controller.rb
    ../app/models/question_answer_vote.rb
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
    attr_accessor :comments,
                  :comments_counts,
                  :posts_user_voted
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

  class ::User
    has_many :question_answer_votes
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
    Category.preload_custom_fields(topics.map(&:category), %w[
      qa_enabled
      qa_disable_like_on_answers
      qa_disable_like_on_questions
      qa_disable_like_on_comments
    ])
  end


  TopicView.on_preload do |topic_view|
    topic_view.comments = {}

    post_ids = topic_view.posts.pluck(:id)
    post_ids_sql = post_ids.join(",")

    comment_post_ids_sql = <<~SQL
    SELECT
      post_replies.reply_post_id
    FROM post_replies
    INNER JOIN LATERAL (
      SELECT 1
      FROM (
        SELECT
          posts.id AS post_id
        FROM posts
        INNER JOIN post_replies pr2 ON posts.id = pr2.reply_post_id
        WHERE pr2.post_id = post_replies.post_id
        AND posts.post_type = #{Post.types[:regular].to_i}
        ORDER BY posts.post_number ASC
        LIMIT 2
      ) X
      WHERE X.post_id = post_replies.reply_post_id
    ) Y ON true
    WHERE post_replies.post_id IN (#{post_ids_sql})
    SQL

    Post.where("id IN (#{comment_post_ids_sql})").order(post_number: :asc).each do |post|
      topic_view.comments[post.reply_to_post_number] ||= []
      topic_view.comments[post.reply_to_post_number] << post
    end

    comments_counts_sql = <<~SQL
    SELECT
      post_replies.post_id,
      COUNT(*) AS comments_count
    FROM post_replies
    WHERE post_replies.post_id IN (#{post_ids_sql})
    GROUP BY post_replies.post_id
    SQL

    topic_view.comments_counts = {}

    DB.query(comments_counts_sql).each do |result|
      topic_view.comments_counts[result.post_id] = result.comments_count
    end

    topic_view.posts_user_voted = {}

    if topic_view.guardian.user
      QuestionAnswerVote
        .where(user: topic_view.guardian.user, post_id: post_ids)
        .pluck(:post_id, :direction)
        .each do |post_id, direction|

        topic_view.posts_user_voted[post_id] = direction
      end
    end
  end

  SiteSetting.enable_filtered_replies_view = true
end
