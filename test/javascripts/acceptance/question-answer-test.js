import {
  click,
  fillIn,
  settled,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "I18n";

const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
const topicList = cloneJSON(discoveryFixtures["/latest.json"]);

function qaEnabledTopicResponse() {
  topicResponse.post_stream.posts[0]["qa_vote_count"] = 0;
  topicResponse.post_stream.posts[0]["comments_count"] = 1;
  topicResponse.post_stream.posts[0]["qa_has_votes"] = false;

  topicResponse.post_stream.posts[0]["comments"] = [
    {
      id: 1,
      user_id: 12345,
      name: "Some Name",
      username: "someusername",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 1</p>",
    },
  ];

  topicResponse.post_stream.posts[1]["qa_vote_count"] = 2;
  topicResponse.post_stream.posts[1]["qa_has_votes"] = true;
  topicResponse.post_stream.posts[1]["comments_count"] = 6;
  topicResponse.post_stream.posts[1]["qa_user_voted_direction"] = "up";

  topicResponse.post_stream.posts[1]["comments"] = [
    {
      id: 2,
      user_id: 12345,
      name: "Some Name",
      username: "someusername",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 2</p>",
      qa_vote_count: 0,
      user_voted: false,
    },
    {
      id: 3,
      user_id: 12345,
      name: "Some Name",
      username: "someusername",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 3</p>",
      qa_vote_count: 3,
      user_voted: false,
    },
    {
      id: 4,
      user_id: 123456,
      name: "Some Name 2 ",
      username: "someusername2",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 4</p>",
      qa_vote_count: 0,
      user_voted: false,
    },
    {
      id: 5,
      user_id: 1234567,
      name: "Some Name 3 ",
      username: "someusername3",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 5</p>",
      qa_vote_count: 0,
      user_voted: false,
    },
    {
      id: 6,
      user_id: 12345678,
      name: "Some Name 4 ",
      username: "someusername4",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 6</p>",
      qa_vote_count: 0,
      user_voted: false,
    },
  ];

  topicResponse["is_qa"] = true;

  return topicResponse;
}

function qaTopicListResponse() {
  // will link to OP
  topicList.topic_list.topics[0].is_qa = true;
  topicList.topic_list.topics[0].last_read_post_number =
    topicList.topic_list.topics[0].highest_post_number;

  // will sort by activity
  topicList.topic_list.topics[1].is_qa = true;
  topicList.topic_list.topics[1].last_read_post_number =
    topicList.topic_list.topics[1].highest_post_number - 2;

  // will link to last post
  topicList.topic_list.topics[3].is_qa = true;
  topicList.topic_list.topics[3].last_read_post_number =
    topicList.topic_list.topics[3].highest_post_number - 1;

  return topicList;
}

let filteredByActivity = false;

function setupQA(needs) {
  needs.settings({
    qa_enabled: true,
    min_post_length: 5,
    qa_comment_max_raw_length: 20,
  });

  needs.hooks.afterEach(() => {
    filteredByActivity = false;
  });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", (request) => {
      if (request.queryParams.filter === "activity") {
        filteredByActivity = true;
      } else {
        filteredByActivity = false;
      }

      return helper.response(qaEnabledTopicResponse());
    });

    server.get("/qa/comments", () => {
      return helper.response({
        comments: [
          {
            id: 7,
            user_id: 12345678,
            name: "Some Name 4",
            username: "someusername4",
            created_at: "2022-01-12T08:21:54.175Z",
            cooked: "<p>Test comment 7</p>",
            qa_vote_count: 0,
            user_voted: false,
          },
        ],
      });
    });

    server.post("/qa/comments", () => {
      return helper.response({
        id: 9,
        user_id: 12345678,
        name: "Some Name 5",
        username: "someusername5",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment 9</p>",
        qa_vote_count: 0,
        user_voted: false,
      });
    });

    server.delete("/qa/comments", () => {
      return helper.response({});
    });

    server.put("/qa/comments", () => {
      return helper.response({
        id: 1,
        user_id: 12345,
        name: "Some Name",
        username: "someusername",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>editing this</p>",
        qa_vote_count: 0,
        user_voted: false,
      });
    });

    server.post("/qa/vote/comment", () => {
      return helper.response({});
    });

    server.delete("/qa/vote/comment", () => {
      return helper.response({});
    });

    server.get("/latest.json", () => {
      return helper.response(qaTopicListResponse());
    });
  });
}

acceptance("Discourse Question Answer - anon user", function (needs) {
  setupQA(needs);

  test("Viewing comments", async function (assert) {
    await visit("/t/280");

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      1,
      "displays the right number of comments for the first post"
    );

    assert.strictEqual(
      queryAll("#post_2 .qa-comment").length,
      5,
      "displays the right number of comments for the second post"
    );

    await click(".qa-comments-menu-show-more-link");

    assert.strictEqual(
      queryAll("#post_2 .qa-comment").length,
      6,
      "displays the right number of comments after loading more"
    );
  });

  test("adding a comment", async function (assert) {
    await visit("/t/280");
    await click(".qa-comment-add-link");

    assert.ok(exists(".login-modal"), "displays the login modal");
  });

  test("voting a comment", async function (assert) {
    await visit("/t/280");
    await click("#post_2 #qa-comment-2 .qa-button-upvote");

    assert.ok(exists(".login-modal"), "displays the login modal");
  });
});

acceptance("Discourse Question Answer - logged in user", function (needs) {
  setupQA(needs);
  needs.user();

  test("Q&A features do not leak into non-Q&A topics", async function (assert) {
    await visit("/t/130");

    assert.ok(exists("#post_1 button.reply"), "displays the reply button");

    assert.notOk(
      exists(".qa-answers-header"),
      "does not display the Q&A answers header"
    );
  });

  test("non Q&A topics do not have Q&A specific class on body tag", async function (assert) {
    await visit("/t/130");

    assert.notOk(
      !!document.querySelector("body.qa-topic"),
      "does not append Q&A specific class on body tag"
    );

    await visit("/t/280");

    assert.ok(
      !!document.querySelector("body.qa-topic"),
      "appends Q&A specific class on body tag"
    );

    await visit("/t/130");

    assert.notOk(
      !!document.querySelector("body.qa-topic"),
      "does not append Q&A specific class on body tag"
    );
  });

  test("sorting post stream by activity and votes", async function (assert) {
    await visit("/t/280");

    assert.ok(
      query(".qa-answers-headers-sort-votes[disabled=true]"),
      "sort by votes button is disabled by default"
    );

    assert.ok(
      !!document.querySelector("body.qa-topic"),
      "appends the right class to body when loading Q&A topic"
    );

    await click(".qa-answers-headers-sort-activity");

    assert.ok(
      filteredByActivity,
      "refreshes post stream with the right filter"
    );

    assert.ok(
      !!document.querySelector("body.qa-topic-sort-by-activity"),
      "appends the right class to body when topic is filtered by activity"
    );

    assert.ok(
      query(".qa-answers-headers-sort-activity[disabled=true]"),
      "disabled sort by activity button"
    );

    await click(".qa-answers-headers-sort-votes");

    assert.ok(
      query(".qa-answers-headers-sort-votes[disabled=true]"),
      "disables sort by votes button"
    );

    assert.ok(
      !!document.querySelector("body.qa-topic"),
      "appends the right class to body when topic is filtered by votes"
    );

    assert.notOk(
      filteredByActivity,
      "removes activity filter from post stream"
    );
  });

  test("reply buttons are hidden in post stream except for the first post", async function (assert) {
    await visit("/t/280");

    assert.ok(
      exists("#post_1 .reply"),
      "reply button is shown for the first post"
    );

    assert.notOk(
      exists("#post_2 .reply"),
      "reply button is only shown for the first post"
    );
  });

  test("validations for comment length", async function (assert) {
    await visit("/t/280");
    await click("#post_1 .qa-comment-add-link");

    await fillIn(".qa-comment-composer-textarea", "a".repeat(4));

    assert.strictEqual(
      query(".qa-comment-composer-flash").textContent.trim(),
      I18n.t("qa.post.qa_comment.composer.too_short", { count: 5 }),
      "displays the right message about raw length when it is too short"
    );

    await fillIn(".qa-comment-composer-textarea", "a".repeat(6));

    assert.strictEqual(
      query(".qa-comment-composer-flash").textContent.trim(),
      I18n.t("qa.post.qa_comment.composer.length_ok", { count: 14 }),
      "displays the right message about raw length when it is OK"
    );

    await fillIn(".qa-comment-composer-textarea", "a".repeat(21));

    assert.strictEqual(
      query(".qa-comment-composer-flash").textContent.trim(),
      I18n.t("qa.post.qa_comment.composer.too_long", { count: 20 }),
      "displays the right message about raw length when it is too long"
    );
  });

  test("adding a comment", async function (assert) {
    await visit("/t/280");

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      1,
      "displays the right number of comments for the first post"
    );

    await click("#post_1 .qa-comment-add-link");

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      2,
      "loads all comments when composer is expanded"
    );

    await fillIn(".qa-comment-composer-textarea", "this is some comment");
    await click(".qa-comments-menu-composer-submit");

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      3,
      "should add the new comment"
    );
  });

  test("adding a comment with keyboard shortcut", async function (assert) {
    await visit("/t/280");
    await click("#post_1 .qa-comment-add-link");

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      2,
      "loads all comments when composer is expanded"
    );

    await fillIn(".qa-comment-composer-textarea", "this is a new test comment");

    await triggerEvent(".qa-comments-menu-composer-submit", "keydown", {
      key: "Enter",
      ctrlKey: true,
    });

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      3,
      "should add the new comment"
    );
  });

  test("editing a comment", async function (assert) {
    updateCurrentUser({ id: 12345 }); // userId of comments in fixtures

    await visit("/t/280");

    assert.strictEqual(
      query("#post_1 .qa-comment-cooked").textContent,
      "Test comment 1",
      "displays the right content for the given comment"
    );

    await click("#post_1 .qa-comment-actions-edit-link");
    await fillIn("#post_1 .qa-comment-editor-1 textarea", "editing this");

    assert.strictEqual(
      query(".qa-comment-composer-flash").textContent.trim(),
      I18n.t("qa.post.qa_comment.composer.length_ok", { count: 8 }),
      "displays the right message when comment lenght is OK"
    );

    await click("#post_1 .qa-comment-editor-1 .qa-comment-editor-submit");

    assert.strictEqual(
      query("#post_1 .qa-comment-cooked").textContent,
      "editing this",
      "displays the right content after comment has been edited"
    );

    assert.ok(
      !exists("#post_1 .qa-comment-editor-1"),
      "hides editor after comment has been edited"
    );
  });

  test("deleting a comment", async function (assert) {
    updateCurrentUser({ id: 12345 }); // userId of comments in fixtures

    await visit("/t/280");

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      1,
      "displays the right number of comments for the first post"
    );

    await click("#post_1 .qa-comment-actions-delete-link");
    await click("a.btn-primary");

    assert.ok(
      exists("#post_1 #qa-comment-1.qa-comment-deleted"),
      "adds the right class to deleted comment"
    );
  });

  test("deleting a comment after more comments have been loaded", async function (assert) {
    updateCurrentUser({ admin: true });

    await visit("/t/280");

    assert.strictEqual(
      queryAll("#post_2 .qa-comment").length,
      5,
      "displays the right number of comments for the second post"
    );

    await click("#post_2 .qa-comments-menu-show-more-link");

    assert.strictEqual(
      queryAll("#post_2 .qa-comment").length,
      6,
      "appends the loaded comments"
    );

    const comments = queryAll("#post_2 .qa-comment-actions-delete-link");

    await click(comments[comments.length - 1]);
    await click("a.btn-primary");

    assert.ok(
      !exists("#post_2 .qa-comments-menu-show-more-link"),
      "updates the comment count such that show more link is not displayed"
    );

    assert.ok(
      exists("#post_2 #qa-comment-7.qa-comment-deleted"),
      "adds the right class to deleted comment"
    );
  });

  test("vote count display", async function (assert) {
    await visit("/t/280");

    assert.ok(
      !exists("#post_2 #qa-comment-2 .qa-comment-actions-vote-count"),
      "does not display element if vote count is zero"
    );

    assert.strictEqual(
      query("#post_2 #qa-comment-3 .qa-comment-actions-vote-count").textContent,
      "3",
      "displays the right vote count"
    );
  });

  test("voting on a comment and removing vote", async function (assert) {
    await visit("/t/280");

    await click("#post_2 #qa-comment-2 .qa-button-upvote");

    assert.strictEqual(
      query("#post_2 #qa-comment-2 .qa-comment-actions-vote-count").textContent,
      "1",
      "updates the comment vote count correctly"
    );

    await click("#post_2 #qa-comment-2 .qa-button-upvote");

    assert.ok(
      !exists("#post_2 #qa-comment-2 .qa-comment-actions-vote-count"),
      "updates the comment vote count correctly"
    );
  });

  test("topic list link overrides work", async function (assert) {
    await visit("/");

    const firstTopicLink = query(
      ".topic-list-item:first-child .raw-topic-link"
    ).getAttribute("href");
    assert.ok(firstTopicLink.endsWith("/1"));

    const secondTopicLink = query(
      ".topic-list-item:nth-child(2) .raw-topic-link"
    ).getAttribute("href");
    assert.ok(secondTopicLink.endsWith("?filter=activity"));

    const fourthTopicLink = query(
      ".topic-list-item:nth-child(4) .raw-topic-link"
    ).getAttribute("href");
    assert.ok(fourthTopicLink.endsWith("/2"));
  });

  test("receiving user post voted message where current user removed their vote", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 0,
      qa_has_votes: false,
      qa_user_voted_id: 19,
      qa_user_voted_direction: null,
    });

    await settled();

    assert.strictEqual(
      query("#post_2 span.qa-post-toggle-voters").textContent,
      "0",
      "displays the right count"
    );

    assert.notOk(
      exists("#post_2 .qa-button-upvote.qa-button-voted"),
      "does not highlight the upvote button"
    );
  });

  test("receiving user post voted message where post no longer has votes", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 0,
      qa_has_votes: false,
      qa_user_voted_id: 280,
      qa_user_voted_direction: "down",
    });

    await settled();

    assert.strictEqual(
      query("#post_2 span.qa-post-toggle-voters").textContent,
      "0",
      "does not render a button to show post voters"
    );
  });

  test("receiving user post voted message where current user is not the one that voted", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 5,
      qa_has_votes: true,
      qa_user_voted_id: 123456,
      qa_user_voted_direction: "down",
    });

    await settled();

    assert.strictEqual(
      query("#post_2 .qa-post-toggle-voters").textContent,
      "5",
      "displays the right post vote count"
    );

    assert.ok(
      exists("#post_2 .qa-button-upvote.qa-button-voted"),
      "highlights the upvote button for the current user"
    );

    assert.notOk(
      exists("#post_2 .qa-button-downvote.qa-button-voted"),
      "does not highlight the downvote button for the current user"
    );
  });

  test("receiving user post voted message where current user is the one that voted", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 5,
      qa_has_votes: true,
      qa_user_voted_id: 19,
      qa_user_voted_direction: "up",
    });

    await settled();

    assert.strictEqual(
      query("#post_2 .qa-post-toggle-voters").textContent,
      "5",
      "displays the right post vote count"
    );

    assert.ok(
      exists("#post_2 .qa-button-upvote.qa-button-voted"),
      "highlights the upvote button for the current user"
    );
  });

  test("receving post commented message when comment has already been loaded", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_commented",
      id: topicResponse.post_stream.posts[0].id,
      comments_count: 1,
      comment: topicResponse.post_stream.posts[0]["comments"][0],
    });

    await settled();

    assert.ok(
      !exists("#post_1 #qa-comment-5678"),
      "it does not append comment when comment has already been loaded"
    );
  });

  test("receving post commented message when there are no more comments to load ", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_commented",
      id: topicResponse.post_stream.posts[0].id,
      comments_count: 2,
      comment: {
        id: 5678,
        user_id: 12345,
        name: "Some Commenter",
        username: "somecommenter",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment ABC</p>",
      },
    });

    await settled();

    assert.ok(
      query("#post_1 #qa-comment-5678").textContent.includes(
        "Test comment ABC"
      ),
      "it appends comment to comments stream"
    );
  });

  test("receiving post commented message when there are more comments to load", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_commented",
      id: topicResponse.post_stream.posts[1].id,
      comments_count: 7,
      comment: {
        id: 5678,
        user_id: 12345,
        name: "Some Commenter",
        username: "somecommenter",
        created_at: "2022-01-12T08:21:54.175Z",
        cooked: "<p>Test comment ABC</p>",
      },
    });

    await settled();

    assert.ok(
      !exists("#post_2 #qa-comment-5678"),
      "it does not append comment when there are more comments to load"
    );

    assert.ok(
      exists("#post_2 .qa-comments-menu-show-more-link"),
      "updates the comments count to reflect the new comment"
    );
  });

  test("receiving post comment trashed message for a comment that has not been loaded ", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_comment_trashed",
      id: topicResponse.post_stream.posts[1].id,
      comments_count: 5,
      comment_id: 12345,
    });

    await settled();

    assert.notOk(
      exists("#post_2 .qa-comments-menu-show-more-link"),
      "removes the show more comments link"
    );
  });

  test("receving post comment trashed message for a comment that has been loaded", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_comment_trashed",
      id: topicResponse.post_stream.posts[1].id,
      comments_count: 5,
      comment_id: topicResponse.post_stream.posts[1].comments[0].id,
    });

    await settled();

    assert.ok(
      exists("#post_2 #qa-comment-2.qa-comment-deleted"),
      "adds the right class to the comment"
    );
  });

  test("receiving post comment edited message for a comment that has been loaded", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_comment_edited",
      id: topicResponse.post_stream.posts[0].id,
      comment_id: topicResponse.post_stream.posts[0].comments[0].id,
      comment_raw: "this is a new comment raw",
      comment_cooked: "<p>this is a new comment cooked</p>",
    });

    await settled();

    assert.strictEqual(
      query("#post_1 #qa-comment-1 .qa-comment-cooked").textContent.trim(),
      "this is a new comment cooked",
      "it updates the content of the comment"
    );

    await click("#post_1 #qa-comment-1 .qa-comment-actions-edit-link");

    assert.strictEqual(
      query(
        "#post_1 #qa-comment-1 .qa-comment-composer textarea"
      ).textContent.trim(),
      "this is a new comment raw",
      "it updates the content of the comment editor"
    );
  });
});
