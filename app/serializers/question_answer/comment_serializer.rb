# frozen_string_literal: true

class QuestionAnswer::CommentSerializer < ApplicationSerializer
  attributes :id,
             :post_number,
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
