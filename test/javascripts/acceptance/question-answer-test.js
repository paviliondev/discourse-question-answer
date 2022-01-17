import { click, fillIn, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import { cloneJSON } from "discourse-common/lib/object";

function qaEnabledTopicResponse() {
  const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);

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

  topicResponse.post_stream.posts[1]["comments"] = [
    {
      id: 2,
      user_id: 12345,
      name: "Some Name",
      username: "someusername",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 2</p>",
    },
    {
      id: 3,
      user_id: 12345,
      name: "Some Name",
      username: "someusername",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 3</p>",
    },
    {
      id: 4,
      user_id: 123456,
      name: "Some Name 2 ",
      username: "someusername2",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 4</p>",
    },
    {
      id: 5,
      user_id: 1234567,
      name: "Some Name 3 ",
      username: "someusername3",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 5</p>",
    },
    {
      id: 6,
      user_id: 12345678,
      name: "Some Name 4 ",
      username: "someusername4",
      created_at: "2022-01-12T08:21:54.175Z",
      cooked: "<p>Test comment 6</p>",
    },
  ];

  topicResponse.post_stream["qa_enabled"] = true;

  return topicResponse;
}

function setupQA(needs) {
  needs.settings({ qa_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/t/12345.json", () =>
      helper.response(qaEnabledTopicResponse())
    );

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
      });
    });
  });
}

acceptance("Discourse Question Answer - anon user", function (needs) {
  setupQA(needs);

  test("Viewing comments", async function (assert) {
    await visit("/t/12345");

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
    await visit("/t/12345");
    await click(".qa-comment-add-link");

    assert.ok(exists(".login-modal"), "displays the login modal");
  });
});

acceptance("Discourse Question Answer - logged in user", function (needs) {
  setupQA(needs);
  needs.user();

  test("adding a comment", async function (assert) {
    await visit("/t/12345");

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

  test("editing a comment", async function (assert) {
    updateCurrentUser({ id: 12345 }); // userId of comments in fixtures

    await visit("/t/12345");

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

    await visit("/t/12345");

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

    await visit("/t/12345");

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
});
