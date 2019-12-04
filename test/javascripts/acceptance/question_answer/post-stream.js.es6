import createStore from "helpers/create-store";

QUnit.module("model:post-stream");

const buildStream = function(id, stream) {
  const store = createStore();
  const topic = store.createRecord("topic", { id, chunk_size: 5 });
  const ps = topic.get("postStream");
  if (stream) {
    ps.set("stream", stream);
  }
  return ps;
};

QUnit.test("appending posts", assert => {

});

QUnit.test("pre-pending posts", assert => {

});