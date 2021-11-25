# frozen_string_literal: true

Fabricator(:qa_vote, class_name: :question_answer_vote) do
  user
  post
  direction 'up'
end
