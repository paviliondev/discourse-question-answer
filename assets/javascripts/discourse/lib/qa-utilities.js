import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

const vote = function (type, data) {
  return ajax("/qa/vote", {
    type,
    data,
  });
};

const removeVote = function (data) {
  return vote("DELETE", data);
};

const castVote = function (data) {
  return vote("POST", data);
};

const whoVoted = function (data) {
  return ajax("/qa/voters", {
    type: "GET",
    data,
  }).catch(popupAjaxError);
};

export function setAsAnswer(post) {
  return ajax("/qa/set_as_answer", {
    type: "POST",
    data: {
      post_id: post.id,
    },
  }).catch(popupAjaxError);
}

export { removeVote, castVote, whoVoted };
