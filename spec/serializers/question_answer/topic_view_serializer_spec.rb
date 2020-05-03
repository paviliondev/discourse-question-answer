# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::TopicViewSerializerExtension do
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user) { Fabricate(:user) }
  let(:topic_view) { TopicView.new(topic, user) }
  let(:create_serializer) do
    ->() do
      scope = Guardian.new(user)

      TopicViewSerializer.new(topic_view, scope: scope, root: false).as_json
    end
  end
  let(:new_attrs) do
    %i[
      qa_enabled
      qa_votes
      qa_can_vote
      last_answered_at
      last_commented_on
      answer_count
      comment_count
      last_answer_post_number
      last_answerer
    ]
  end
  let(:dependent_attrs) do
    %i[
      last_answered_at
      last_commented_on
      answer_count
      comment_count
      last_answer_post_number
      last_answerer
    ]
  end

  context 'enabled' do
    before do
      category.custom_fields['qa_enabled'] = true
      category.save!
      category.reload
    end

    it 'should return correct values' do
      serializer = create_serializer.call

      expect(serializer[:qa_enabled]).to eq(topic_view.qa_enabled)
      expect(serializer[:qa_votes]).to eq(Topic.qa_votes(topic, user))
      expect(serializer[:qa_can_vote]).to eq(Topic.qa_can_vote(topic, user))

      %i[
        last_answered_at
        last_commented_on
        answer_count
        comment_count
        last_answer_post_number
      ].each do |attr|
        expect(serializer[attr]).to eq(topic.send(attr))
      end

      expect(serializer[:last_answerer].id).to eq(topic.last_answerer.id)
    end
  end

  context 'disabled' do
    before { SiteSetting.qa_enabled = false }

    it 'should not include dependent_attrs' do
      serializer = create_serializer.call

      dependent_attrs.each do |attr|
        expect(serializer.key?(attr)).to eq(false)
      end
    end
  end
end
