import { click, fillIn, triggerEvent, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  publishToMessageBus,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { skip, test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import { cloneJSON } from "discourse-common/lib/object";

const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);

function qaEnabledTopicResponse() {
  topicResponse.post_stream.posts[0]["qa_enabled"] = true;
  topicResponse.post_stream.posts[0]["qa_vote_count"] = 0;
  topicResponse.post_stream.posts[0]["comments_count"] = 1;

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

  topicResponse.post_stream.posts[1]["qa_enabled"] = true;
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

  topicResponse.post_stream["qa_enabled"] = true;

  return topicResponse;
}

let filteredByActivity = false;

function setupQA(needs) {
  needs.settings({ qa_enabled: true });

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
        cooked: "<p>I edited this comment</p>",
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
    await click("#post_2 .qa-comment-2 .qa-button-upvote");

    assert.ok(exists(".login-modal"), "displays the login modal");
  });
});

acceptance("Discourse Question Answer - logged in user", function (needs) {
  setupQA(needs);
  needs.user();

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

    await fillIn(
      ".qa-comments-menu-composer-textarea",
      "this is a new test comment"
    );

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

    await fillIn(
      ".qa-comments-menu-composer-textarea",
      "this is a new test comment"
    );

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
    await fillIn(
      "#post_1 .qa-comment-editor-1 textarea",
      "I edited this comment"
    );
    await click("#post_1 .qa-comment-editor-1 .qa-comment-editor-submit");

    assert.strictEqual(
      query("#post_1 .qa-comment-cooked").textContent,
      "I edited this comment",
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

    assert.strictEqual(
      queryAll("#post_1 .qa-comment").length,
      0,
      "comment is removed after being deleted"
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

    assert.strictEqual(
      queryAll("#post_2 .qa-comment").length,
      5,
      "removes deleted comment"
    );
  });

  test("vote count display", async function (assert) {
    await visit("/t/280");

    assert.ok(
      !exists("#post_2 .qa-comment-2 .qa-comment-actions-vote-count"),
      "does not display element if vote count is zero"
    );

    assert.strictEqual(
      query("#post_2 .qa-comment-3 .qa-comment-actions-vote-count").textContent,
      "3",
      "displays the right vote count"
    );
  });

  test("voting on a comment and removing vote", async function (assert) {
    await visit("/t/280");

    await click("#post_2 .qa-comment-2 .qa-button-upvote");

    assert.strictEqual(
      query("#post_2 .qa-comment-2 .qa-comment-actions-vote-count").textContent,
      "1",
      "updates the comment vote count correctly"
    );

    await click("#post_2 .qa-comment-2 .qa-button-upvote");

    assert.ok(
      !exists("#post_2 .qa-comment-2 .qa-comment-actions-vote-count"),
      "updates the comment vote count correctly"
    );
  });

  // Skip message bus tests but keep it around for development use. We currently do not have a reliable way to wait for
  // widgets to re-render and this results in all kinds of timing issues. For example, this test passes in the browser
  // but fails when ran in headless mode.
  skip("receiving user post voted message where current user removed their vote", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 0,
      qa_has_votes: false,
      qa_user_voted_id: 19,
      qa_user_voted_direction: null,
    });

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

  skip("receiving user post voted message where post no longer has votes", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 0,
      qa_has_votes: false,
      qa_user_voted_id: 280,
      qa_user_voted_direction: "down",
    });

    assert.strictEqual(
      query("#post_2 span.qa-post-toggle-voters").textContent,
      "0",
      "does not render a button to show post voters"
    );
  });

  skip("receiving user post voted message where current user is not the one that voted", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 5,
      qa_has_votes: true,
      qa_user_voted_id: 123456,
      qa_user_voted_direction: "down",
    });

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

  skip("receiving user post voted message where current user is the one that voted", async function (assert) {
    await visit("/t/280");

    publishToMessageBus("/topic/280", {
      type: "qa_post_voted",
      id: topicResponse.post_stream.posts[1].id,
      qa_vote_count: 5,
      qa_has_votes: true,
      qa_user_voted_id: 19,
      qa_user_voted_direction: "up",
    });

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
});
