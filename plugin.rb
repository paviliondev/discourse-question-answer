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
    ../lib/question_answer/vote.rb
    ../extensions/category_extension.rb
    ../extensions/category_custom_field_extension.rb
    ../extensions/guardian_extension.rb
    ../extensions/post_action_type_extension.rb
    ../extensions/post_creator_extension.rb
    ../extensions/post_extension.rb
    ../extensions/post_serializer_extension.rb
    ../extensions/topic_extension.rb
    ../extensions/topic_list_item_serializer_extension.rb
    ../extensions/topic_tag_extension.rb
    ../extensions/topic_view_extension.rb
    ../extensions/topic_view_serializer_extension.rb
    ../app/controllers/question_answer/votes_controller.rb
    ../app/models/question_answer_vote.rb
    ../config/routes.rb
    ../jobs/update_category_post_order.rb
    ../jobs/update_topic_post_order.rb
    ../jobs/qa_update_topics_post_order.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  if respond_to?(:register_svg_icon)
    register_svg_icon 'angle-up'
    register_svg_icon 'info'
  end

  %w[
    qa_enabled
    qa_one_to_many
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

  class ::Guardian
    attr_accessor :post_opts
    prepend QuestionAnswer::GuardianExtension
  end

  class ::PostCreator
    prepend QuestionAnswer::PostCreatorExtension
  end

  class ::PostSerializer
    attributes(
      :qa_vote_count,
      :qa_voted,
      :qa_enabled,
      :last_answerer,
      :last_answered_at,
      :answer_count,
      :last_answer_post_number
    )

    prepend QuestionAnswer::PostSerializerExtension
  end

  register_post_custom_field_type('vote_history', :json)
  register_post_custom_field_type('vote_count', :integer)

  class ::Post
    include QuestionAnswer::PostExtension
  end

  PostActionType.types[:vote] = 100

  class ::PostActionType
    singleton_class.prepend QuestionAnswer::PostActionTypeExtension
  end

  class ::Topic
    include QuestionAnswer::TopicExtension
  end

  class ::TopicView
    prepend QuestionAnswer::TopicViewExtension
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

  class ::CategoryCustomField
    include QuestionAnswer::CategoryCustomFieldExtension
  end

  class ::TopicTag
    include QuestionAnswer::TopicTagExtension
  end

  # TODO: Performance of the query degrades as the number of posts a user has voted
  # on increases. We should probably keep a counter cache in the user's
  # custom fields.
  add_to_class(:user, :vote_count) do
    PostCustomField
      .joins(post: :user)
      .where("users.id = ?", self.id)
      .where(name: 'vote_count')
      .sum('value::int')
  end

  add_to_serializer(:user_card, :vote_count) do
    object.vote_count
  end

  class ::User
    has_many :question_answer_votes
  end
end
