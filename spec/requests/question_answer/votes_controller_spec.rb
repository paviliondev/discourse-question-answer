# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionAnswer::VotesController do
  fab!(:tag) { Fabricate(:tag) }
  fab!(:topic) { Fabricate(:topic, tags: [tag]) }
  fab!(:qa_post) { Fabricate(:post, topic: topic) } # don't set this as :post
  fab!(:qa_user) { Fabricate(:user) }

  fab!(:qa_answer) do
    create_post(
      raw: "some raw here",
      topic_id: topic.id,
      reply_to_post_number: qa_post.post_number
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

      post '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(403)
    end

    it 'should return the right response if plugin is disabled' do
      SiteSetting.qa_enabled = false

      post '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(403)
    end

    it 'should success if never voted' do
      post '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(200)

      vote = qa_post.question_answer_votes.first

      expect(vote.post_id).to eq(qa_post.id)
      expect(vote.user_id).to eq(qa_user.id)
    end

    it 'should error if already voted' do
      post '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(200)

      post '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(403)
    end
  end

  describe '#destroy' do
    before { sign_in(qa_user) }

    it 'should success if has voted' do
      post '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(200)

      vote = qa_post.question_answer_votes.first

      expect(vote.post_id).to eq(qa_post.id)
      expect(vote.user_id).to eq(qa_user.id)

      delete '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(200)
      expect(QuestionAnswerVote.exists?(id: vote.id)).to eq(false)
    end

    it 'should return the right response if user has never voted on post' do
      delete '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(403)
    end

    it 'should cant undo vote' do
      SiteSetting.qa_undo_vote_action_window = 1

      post "/qa/vote.json", params: { post_id: qa_post.id }

      expect(response.status).to eq(200)

      freeze_time 2.minutes.from_now do
        delete '/qa/vote.json', params: { post_id: qa_post.id }

        expect(response.status).to eq(403)

        msg = I18n.t('vote.error.undo_vote_action_window', minutes: 1)

        expect(JSON.parse(response.body)['errors'][0]).to eq(msg)
      end
    end
  end

  describe '#voters' do
    before { sign_in(qa_user) }

    it 'should return the right response if post does not exist' do
      get '/qa/voters.json', params: { post_id: -1 }

      expect(response.status).to eq(404)
    end

    it 'should return correct users' do
      post '/qa/vote.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(200)

      get '/qa/voters.json', params: { post_id: qa_post.id }

      expect(response.status).to eq(200)

      parsed = JSON.parse(response.body)

      expect(parsed['voters'].map { |u| u['id'] })
        .to contain_exactly(qa_user.id)
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
