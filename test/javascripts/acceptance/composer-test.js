import { click, fillIn, visit } from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import I18n from "I18n";
import { parsePostData } from "discourse/tests/helpers/create-pretender";
import Category from "discourse/models/category";

let createAsQASetInRequest = false;

acceptance("Discourse Question Answer - composer", function (needs) {
  needs.user();
  needs.settings({ qa_enabled: true });

  needs.hooks.afterEach(() => {
    createAsQASetInRequest = false;
  });

  needs.pretender((server, helper) => {
    server.post("/posts", (request) => {
      if (parsePostData(request.requestBody).create_as_qa === "true") {
        createAsQASetInRequest = true;
      }

      return helper.response({
        post: {
          topic_id: 280,
        },
      });
    });
  });

  test("Creating new topic with Q&A format", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const composerActions = selectKit(".composer-actions");
    await composerActions.expand();
    await composerActions.selectKitSelectRowByName(
      I18n.t("composer.composer_actions.create_as_qa.label")
    );

    assert.strictEqual(
      query(".action-title").textContent.trim(),
      I18n.t("composer.create_qa.label"),
      "displays the right composer action title when creating Q&A topic"
    );

    assert.strictEqual(
      query(".create .d-button-label").textContent.trim(),
      I18n.t("composer.create_qa.label"),
      "displays the right label for composer create button"
    );

    await composerActions.expand();
    await composerActions.selectKitSelectRowByName(
      I18n.t("composer.composer_actions.remove_as_qa.label")
    );

    assert.notStrictEqual(
      query(".action-title").textContent.trim(),
      I18n.t("composer.create_qa.label"),
      "reverts to original composer title when Q&A format is disabled"
    );

    await composerActions.expand();
    await composerActions.selectKitSelectRowByName(
      I18n.t("composer.composer_actions.create_as_qa.label")
    );

    await fillIn("#reply-title", "this is some random topic title");
    await fillIn(".d-editor-input", "this is some random body");
    await click(".create");

    assert.ok(
      createAsQASetInRequest,
      "submits the right request to create topic as Q&A formatted"
    );
  });

  test("Creating new topic in category with Q&A create default", async function (assert) {
    Category.findById(2).set("create_as_qa_default", true);

    await visit("/");
    await click("#create-topic");

    assert.strictEqual(
      query(".action-title").innerText.trim(),
      I18n.t("topic.create_long")
    );

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert.strictEqual(
      query(".action-title").innerText.trim(),
      I18n.t("composer.create_qa.label")
    );
  });
});
