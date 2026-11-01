// Database helpers for handlers: awaited commit, explicit rollback, SQLSTATE to catalog mapping.
#pragma once
#include <coroutine>
#include <memory>
#include <string>

#include <drogon/drogon.h>
#include <drogon/orm/DbClient.h>

#include "db_config.h"
#include "http_support.h"

namespace ma {

inline constexpr const char* kDbClientName = "ma";

// Drogon commits when the last reference to a Transaction is released, and reports the outcome through a callback.
// Awaiting that callback means the handler never answers 2xx before the commit is confirmed by the server.
struct CommitAwaiter {
  struct State {
    std::coroutine_handle<> continuation;
    bool completed{false};
    bool ok{false};
    // Both timer and DB callback are serialized onto the app loop. A late
    // callback owns this state, never the already-destroyed coroutine frame.
    void finish(bool success) {
      if (completed) return;
      completed = true;
      ok = success;
      continuation.resume();
    }
  };
  std::shared_ptr<drogon::orm::Transaction> trans;
  std::shared_ptr<State> state{std::make_shared<State>()};
  bool await_ready() const noexcept { return false; }
  void await_suspend(std::coroutine_handle<> h) {
    auto shared = state;
    shared->continuation = h;
    auto* loop = drogon::app().getLoop();
    auto t = std::move(trans);
    t->setCommitCallback([shared, loop](bool success) {
      loop->queueInLoop([shared, success] { shared->finish(success); });
    });
    // No access to the awaiter/frame after publishing the continuation to a timer.
    loop->runAfter(db_limits().client_seconds(), [weak = std::weak_ptr<State>(shared)] {
      if (auto pending = weak.lock()) pending->finish(false);
    });
    t.reset();  // releases the last reference: Drogon sends COMMIT
  }
  bool await_resume() const noexcept { return state->ok; }
};

inline CommitAwaiter commit(std::shared_ptr<drogon::orm::Transaction> t) { return CommitAwaiter{std::move(t)}; }

inline void rollback_quietly(const std::shared_ptr<drogon::orm::Transaction>& t) noexcept {
  try {
    if (t) t->rollback();
  } catch (...) {
  }
}

// Maps a PostgreSQL SQLSTATE raised by our functions to a catalog response. Never forwards database text to the client.
inline drogon::HttpResponsePtr response_for_sqlstate(const std::string& state, const std::string& rid) {
  if (state == "55P03" || state == "40001")  // lock timeout, or a claim that raced with cleanup: retry the same request
    return error_response("CONFLICT", "another identical request is still in progress; retry", rid, true);
  if (state == "57014" || state.rfind("08", 0) == 0 || state == "57P01" || state == "57P02" || state == "57P03")
    return error_response("SERVICE_UNAVAILABLE", "database unavailable or deadline exceeded", rid, true);
  if (state == "53400") return error_response("VALIDATION_FAILED", "account limit reached", rid);
  if (state == "23514") return error_response("VALIDATION_FAILED", "value out of range", rid);
  if (state == "22007" || state == "22008") return error_response("VALIDATION_FAILED", "invalid date-time value", rid);
  if (state == "22021" || state == "22P05") return error_response("INVALID_REQUEST", "invalid character in request", rid);
  return error_response("INTERNAL_ERROR", "unexpected server error", rid);
}

}  // namespace ma
