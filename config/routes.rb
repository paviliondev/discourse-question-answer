# frozen_string_literal: true

QuestionAnswer::Engine.routes.draw do
  resource :vote
  get 'voters' => 'votes#voters'
end

Discourse::Application.routes.append do
  mount ::QuestionAnswer::Engine, at: 'qa'
end
