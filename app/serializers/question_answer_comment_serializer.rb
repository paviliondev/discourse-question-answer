# frozen_string_literal: true

class QuestionAnswerCommentSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :username,
             :created_at,
             :cooked

  def name
    object.user.name
  end

  def username
    object.user.username
  end
end
