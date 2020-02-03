import { popupAjaxError } from "discourse/lib/ajax-error";
import { ajax } from "discourse/lib/ajax";

const voteActionId = 100;

const vote = function(type, data) {
  return ajax("/qa/vote", {
    type,
    data
  }).catch(popupAjaxError);
};

const undoVote = function(data) {
  return vote("DELETE", data);
};

const castVote = function(data) {
  return vote("POST", data);
};

const whoVoted = function(data) {
  return ajax("/qa/voters", {
    type: "GET",
    data
  }).catch(popupAjaxError);
};

export { undoVote, castVote, voteActionId, whoVoted };
