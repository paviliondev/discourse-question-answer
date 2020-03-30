# frozen_string_literal: true

require 'rails_helper'

Fabricator(:comment, from: :post) do
  reply_to_post_number
end

describe QuestionAnswer::TopicExtension do
  fab!(:user)  { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:answers) do
    5.times.map { Fabricate(:post, topic: topic) }.sort_by { |a| a.created_at }
  end
  fab!(:comments) do
    answer_post_nums = answers.map(&:post_number)

    5.times.map do
      Fabricate(
        :comment,
        topic: topic,
        reply_to_post_number: answer_post_nums.sample
      )
    end.sort_by { |c| c.created_at }
  end

  it 'should return correct comments' do
    comment_ids = comments.map(&:id)
    topic_comment_ids = topic.comments.pluck(:id)

    expect(comment_ids).to eq(topic_comment_ids)
  end

  it 'should return correct answers' do
    answer_ids = answers.map(&:id)
    topic_answer_ids = topic.answers.pluck(:id)

    expect(answer_ids).to eq(topic_answer_ids)
  end

  it 'should return correct answer_count' do
    expect(topic.answers.size).to eq(answers.size)
  end

  it 'should return correct comment_count' do
    expect(topic.comments.size).to eq(comments.size)
  end

  it 'should return correct last_answered_at' do
    expected = answers.last.created_at

    expect(topic.last_answered_at).to eq(expected)
  end

  it 'should return correct last_commented_on' do
    expected = comments.last.created_at

    expect(topic.last_commented_on).to eq(expected)
  end

  it 'should return correct last_answer_post_number' do
    expected = answers.last.post_number

    expect(topic.last_answer_post_number).to eq(expected)
  end

  it 'should return correct last_answerer' do
    expected = answers.last.user.id

    expect(topic.last_answerer.id).to eq(expected)
  end
end
