# name: discourse-qa
# about: QnA Style Topics
# version: 0.1
# authors: Angus McLeod

register_asset 'stylesheets/qa-styles.scss', :desktop

after_initialize do
  Category.register_custom_field_type('qa_enabled', :boolean)

  module ::DiscourseQa
    class Engine < ::Rails::Engine
      engine_name "discourse_qa"
      isolate_namespace DiscourseQa
    end
  end

  require_dependency "application_controller"
  class DiscourseQa::QaController < ::ApplicationController
    def vote
      post = Post.find(params[:id].to_i)
      post.custom_fields["qa_count"] = post.custom_fields["qa_count"].to_i + params[:change].to_i
      post.save!
      msg = {
        updated_at: Time.now,
        post_id: post.id,
        type: "revised"
      }
      MessageBus.publish("/topic/#{post.topic.id}", msg, group_ids: post.topic.secure_group_ids)
      render json: success_json
    end
  end

  DiscourseQa::Engine.routes.draw do
    post "/vote" => "qa#vote"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseQa::Engine, at: "qa"
  end

  module QAHelper
    class << self
      def qa_enabled(topic)
        tags = topic.tags.map(&:name)
        has_qa_tag = !(tags & SiteSetting.qa_tags.split('|')).empty?
        is_qa_category = topic.category && topic.category.custom_fields["qa_enabled"]
        has_qa_tag || is_qa_category
      end
    end
  end

  DiscourseEvent.on(:post_created) do |post, opts, user|
    if QAHelper.qa_enabled(post.topic)
      post.custom_fields['qa_count'] = 0
      post.save!
    end
  end

  TopicView.add_post_custom_fields_whitelister do |user|
    ["qa_count"]
  end

  add_to_serializer(:topic_view, :qa_enabled) {QAHelper.qa_enabled(object.topic)}
  add_to_serializer(:basic_category, :qa_enabled) {object.custom_fields["qa_enabled"]}
  add_to_serializer(:post, :qa_count) {post_custom_fields["qa_count"]}
end
