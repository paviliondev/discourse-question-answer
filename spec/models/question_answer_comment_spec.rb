# frozen_string_literal: true

require 'rails_helper'

describe QuestionAnswerComment do
  fab!(:topic) { Fabricate(:topic, subtype: Topic::QA_SUBTYPE) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user) { Fabricate(:user) }
  fab!(:tag) { Fabricate(:tag) }

  before do
    SiteSetting.qa_enabled = true
  end

  context 'validations' do
    it 'does not allow comments to be created when post is in reply to another post' do
      post_2 = Fabricate(:post, topic: topic)

      SiteSetting.qa_enabled = false

      post_3 = Fabricate(:post, topic: topic, reply_to_post_number: post_2.post_number)

      SiteSetting.qa_enabled = true

      qa_comment = QuestionAnswerComment.new(raw: 'this is a **post**', post: post_3, user: user)

      expect(qa_comment.valid?).to eq(false)
      expect(qa_comment.errors.full_messages).to contain_exactly(I18n.t("qa.comment.errors.not_permitted"))
    end

    it 'does not allow comments to be created when SiteSetting.qa_comment_limit_per_post has been reached' do
      SiteSetting.qa_comment_limit_per_post = 1

      QuestionAnswerComment.create!(raw: 'this is a **post**', post: post, user: user)
      qa_comment = QuestionAnswerComment.new(raw: 'this is a **post**', post: post, user: user)

      expect(qa_comment.valid?).to eq(false)

      expect(qa_comment.errors.full_messages).to contain_exactly(
        I18n.t("qa.comment.errors.limit_exceeded", limit: SiteSetting.qa_comment_limit_per_post)
      )
    end

    it 'does not allow comment to be created when raw does not meet min_post_length site setting' do
      SiteSetting.min_post_length = 5

      qa_comment = QuestionAnswerComment.new(raw: '1234', post: post, user: user)

      expect(qa_comment.valid?).to eq(false)
      expect(qa_comment.errors[:raw]).to eq([I18n.t('errors.messages.too_short', count: 5)])
    end

    it "does not allow comment to be created when raw length exceeds qa_comment_max_raw_length site setting" do
      max = SiteSetting.qa_comment_max_raw_length
      length = max + 1

      qa_comment = QuestionAnswerComment.new(
        raw: '1' * length,
        post: post,
        user: user
      )

      expect(qa_comment.valid?).to eq(false)
      expect(qa_comment.errors[:raw]).to eq([I18n.t('errors.messages.too_long_validation', max: max, length: length)])
    end
  end

  context 'callbacks' do
    it 'cooks raw before saving' do
      qa_comment = QuestionAnswerComment.new(raw: 'this is a **post**', post: post, user: user)

      expect(qa_comment.valid?).to eq(true)
      expect(qa_comment.cooked).to eq("<p>this is a <strong>post</strong></p>")
      expect(qa_comment.cooked_version).to eq(described_class::COOKED_VERSION)
    end
  end

  describe '.cook' do
    it 'supports emphasis markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "**bold**")

      expect(qa_comment.cooked).to eq("<p><strong>bold</strong></p>")
    end

    it 'supports backticks markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "`test`")

      expect(qa_comment.cooked).to eq("<p><code>test</code></p>")
    end

    it 'supports link markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "[test link](https://www.example.com)")

      expect(qa_comment.cooked).to eq("<p><a href=\"https://www.example.com\" rel=\"noopener nofollow ugc\">test link</a></p>")
    end

    it 'supports linkify markdown rule' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: "https://www.example.com")

      expect(qa_comment.cooked).to eq("<p><a href=\"https://www.example.com\" rel=\"noopener nofollow ugc\">https://www.example.com</a></p>")
    end

    it 'supports emoji markdown engine' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: ':grin: abcde')

      expect(qa_comment.cooked).to eq("<p><img src=\"/images/emoji/twitter/grin.png?v=#{Emoji::EMOJI_VERSION}\" title=\":grin:\" class=\"emoji\" alt=\":grin:\" loading=\"lazy\" width=\"20\" height=\"20\"> abcde</p>")
    end

    it 'supports censored markdown engine' do
      watched_word = Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "testing")

      qa_comment = Fabricate(:qa_comment, post: post, raw: watched_word.word)

      expect(qa_comment.cooked).to eq("<p>■■■■■■■</p>")
    end

    it 'removes newlines from raw as comments should only support a single paragraph' do
      qa_comment = Fabricate(:qa_comment, post: post, raw: <<~RAW)
      line 1

      line 2
      RAW

      expect(qa_comment.cooked).to eq("<p>line 1 line 2</p>")
    end
  end
end
