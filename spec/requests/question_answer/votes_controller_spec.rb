# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionAnswer::VotesController do
  fab!(:tag) { Fabricate(:tag) }
  fab!(:topic) { Fabricate(:topic, tags: [tag]) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:answer) { Fabricate(:post, topic: topic) }
  fab!(:answer_2) { Fabricate(:post, topic: topic) }
  fab!(:qa_user) { Fabricate(:user) }

  fab!(:qa_answer) do
    create_post(
      raw: "some raw here",
      topic_id: topic.id,
      reply_to_post_number: answer.post_number
    )
  end

  fab!(:admin) { Fabricate(:admin) }
  fab!(:category) { Fabricate(:category) }

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
  end

  describe '#create' do
    before { sign_in(qa_user) }

    it 'returns the right response when user does not have access to post' do
      topic.update!(category: category)
      category.update!(read_restricted: true)

      post '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(403)
    end

    it 'should return the right response if plugin is disabled' do
      SiteSetting.qa_enabled = false

      post '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(403)
    end

    it 'should success if never voted' do
      post '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(200)

      vote = answer.question_answer_votes.first

      expect(vote.post_id).to eq(answer.id)
      expect(vote.user_id).to eq(qa_user.id)
    end

    it 'should error if already voted' do
      post '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(200)

      post '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(403)
    end
  end

  describe '#destroy' do
    before { sign_in(qa_user) }

    it 'should success if has voted' do
      post '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(200)

      vote = answer.question_answer_votes.first

      expect(vote.post_id).to eq(answer.id)
      expect(vote.user_id).to eq(qa_user.id)

      delete '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(200)
      expect(QuestionAnswerVote.exists?(id: vote.id)).to eq(false)
    end

    it 'should return the right response if user has never voted on post' do
      delete '/qa/vote.json', params: { post_id: answer.id }

      expect(response.status).to eq(403)
    end

    it 'should cant undo vote' do
      SiteSetting.qa_undo_vote_action_window = 1

      post "/qa/vote.json", params: { post_id: answer.id }

      expect(response.status).to eq(200)

      freeze_time 2.minutes.from_now do
        delete '/qa/vote.json', params: { post_id: answer.id }

        expect(response.status).to eq(403)

        msg = I18n.t('vote.error.undo_vote_action_window', minutes: 1)

        expect(JSON.parse(response.body)['errors'][0]).to eq(msg)
      end
    end
  end

  describe '#voters' do
    fab!(:user) { Fabricate(:user) }

    it 'should return the right response for an anon user' do
      get '/qa/voters.json', params: { post_id: answer.id }

      expect(response.status).to eq(403)
    end

    it 'should return the right response if post does not exist' do
      sign_in(qa_user)

      get '/qa/voters.json', params: { post_id: -1 }

      expect(response.status).to eq(404)
    end

    it 'should return correct users respecting limits' do
      sign_in(qa_user)

      Fabricate(:qa_vote,
        post: answer,
        user: Fabricate(:user),
        direction: QuestionAnswerVote.directions[:down]
      )

      Fabricate(:qa_vote, post: answer, user: user)

      Fabricate(:qa_vote,
        post: answer,
        user: qa_user,
        direction: QuestionAnswerVote.directions[:down]
      )

      Fabricate(:qa_vote, post: answer_2, user: user)

      stub_const(QuestionAnswer::VotesController, "VOTERS_LIMIT", 2) do
        get '/qa/voters.json', params: { post_id: answer.id }
      end

      expect(response.status).to eq(200)

      parsed = JSON.parse(response.body)
      voters = parsed['voters']

      expect(voters.map { |v| v['id'] }).to contain_exactly(qa_user.id, user.id)

      expect(voters[0]['id']).to eq(qa_user.id)
      expect(voters[0]['username']).to eq(qa_user.username)
      expect(voters[0]['name']).to eq(qa_user.name)
      expect(voters[0]['avatar_template']).to eq(qa_user.avatar_template)
      expect(voters[0]['direction']).to eq(QuestionAnswerVote.directions[:down])

      expect(voters[1]['id']).to eq(user.id)
      expect(voters[1]['direction']).to eq(QuestionAnswerVote.directions[:up])
    end
  end

  describe '#set_as_answer' do
    context 'admin' do
      before { sign_in(admin) }

      it "should set comment as an answer" do
        post '/qa/set_as_answer.json', params: { post_id: qa_answer.id }

        expect(response.status).to eq(200)
        expect(qa_answer.reload.reply_to_post_number).to eq(nil)
        expect(PostReply.exists?(reply_post_id: qa_answer.id)).to eq(false)
      end
    end

    context 'user' do
      before { sign_in(qa_user) }

      it 'should return 403' do
        post '/qa/set_as_answer.json', params: { post_id: qa_answer.id }

        expect(response.status).to eq(403)
      end
    end
  end
end
