# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionAnswer::VotesController do
  fab!(:tag) { Fabricate(:tag) }
  fab!(:topic) { Fabricate(:topic, tags: [tag]) }
  fab!(:qa_post) { Fabricate(:post, topic: topic) } # don't set this as :post
  fab!(:qa_user) { Fabricate(:user) }
  fab!(:qa_answer) { Fabricate(:post, topic: topic, reply_to_post_number: qa_post.post_number) }
  fab!(:admin) { Fabricate(:admin) }

  let(:vote_params) do
    {
      vote: {
        post_id: qa_post.id,
        user_id: qa_user.id,
        direction: QuestionAnswer::Vote::UP
      }
    }
  end
  let(:get_voters) do
    ->(params = nil) { get '/qa/voters.json', params: params || vote_params }
  end
  let(:create_vote) do
    ->(params = nil) { post '/qa/vote.json', params: params || vote_params }
  end
  let(:delete_vote) do
    ->(params = nil) { delete '/qa/vote.json', params: params || vote_params }
  end
  let(:set_as_answer) do
    ->(post_id) { post '/qa/set_as_answer.json', params: { post_id: post_id } }
  end

  before do
    SiteSetting.qa_enabled = true
    SiteSetting.qa_tags = tag.name
  end

  describe '#ensure_logged_in' do
    it 'should return 403 when not logged in' do
      get_voters.call

      expect(response.status).to eq(403)
    end
  end

  context '#find_vote_post' do
    before { sign_in(qa_user) }

    it 'should find post by post_id param' do
      get_voters.call post_id: qa_post.id

      expect(response.status).to eq(200)
    end

    it 'should find post by vote.post_id param' do
      get_voters.call

      expect(response.status).to eq(200)
    end

    it 'should return 404 if no post found' do
      get_voters.call post_id: qa_post.id + 1000

      expect(response.status).to eq(404)
    end
  end

  describe '#find_vote_user' do
    before { sign_in(qa_user) }

    it 'should return 404 if user not found' do
      vote_params[:vote][:user_id] += 1000

      create_vote.call

      expect(response.status).to eq(404)
    end
  end

  describe '#ensure_qa_enabled' do
    it 'should return 403 if plugin disabled' do
      SiteSetting.qa_enabled = false

      sign_in(qa_user)
      create_vote.call

      expect(response.status).to eq(403)
    end
  end

  describe '#create' do
    before { sign_in(qa_user) }

    it 'should success if never voted' do
      create_vote.call

      expect(response.status).to eq(200)
    end

    it 'should error if already voted' do
      create_vote.call
      expect(response.status).to eq(200)

      create_vote.call
      expect(response.status).to eq(403)
    end
  end

  describe '#destroy' do
    before { sign_in(qa_user) }

    it 'should success if has voted' do
      create_vote.call
      delete_vote.call

      expect(response.status).to eq(200)
    end

    it 'should error if never voted' do
      delete_vote.call

      expect(response.status).to eq(403)
    end

    it 'should cant undo vote' do
      # this takes 1 minute just to sleep
      if ENV['QA_TEST_UNDO_VOTE']
        SiteSetting.qa_undo_vote_action_window = 1

        create_vote.call

        sleep 65

        delete_vote.call

        expect(response.status).to eq(403)

        msg = I18n.t('vote.error.undo_vote_action_window', minutes: 1)

        expect(JSON.parse(response.body)['errors'][0]).to eq(msg)
      end
    end
  end

  describe '#voters' do
    before { sign_in(qa_user) }

    it 'should return correct users' do
      create_vote.call
      get_voters.call

      parsed = JSON.parse(response.body)
      users = parsed['voters'].map { |u| u['id'] }

      expect(users.include?(qa_user.id)).to eq(true)
    end
  end

  describe '#set_as_answer' do
    context 'admin' do
      before { sign_in(admin) }

      it "should set comment as an answer" do
        expect(qa_answer.reply_to_post_number).to_not eq(nil)

        set_as_answer.call(qa_answer.id)

        qa_answer.reload

        expect(qa_answer.reply_to_post_number).to eq(nil)
      end
    end

    context 'user' do
      before { sign_in(qa_user) }

      it 'should return 403' do
        set_as_answer.call(qa_answer.id)

        expect(response.status).to eq(403)
      end
    end
  end
end
