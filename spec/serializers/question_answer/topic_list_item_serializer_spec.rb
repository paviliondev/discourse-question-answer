# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswer::TopicListItemSerializerExtension do
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  let(:enable_category) do
    ->() do
      category.custom_fields['qa_enabled'] = true
      category.save!
      category.reload
    end
  end
  let(:create_serializer) do
    ->() do
      TopicListItemSerializer.new(
        topic,
        scope: Guardian.new,
        root: false
      ).as_json
    end
  end
  let(:custom_attrs) do
    %i[qa_enabled answer_count]
  end

  context 'enabled' do
    before do
      enable_category.call
    end

    it 'should include custom attributes' do
      serializer = create_serializer.call

      custom_attrs.each do |attr|
        expect(serializer.key?(attr)).to eq(true)
      end

      expect(serializer[:qa_enabled]).to eq(Topic.qa_enabled(topic))
      expect(serializer[:answer_count]).to eq(topic.answer_count)
    end
  end

  context 'disabled' do
    it 'should not include custom attributes' do
      serializer = create_serializer.call

      custom_attrs.each do |attr|
        expect(serializer.key?(attr)).to eq(false)
      end
    end
  end
end
