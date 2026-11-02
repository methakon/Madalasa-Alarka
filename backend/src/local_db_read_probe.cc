#include "Database.h"
#include <drogon/drogon.h>
#include <charconv>
#include <condition_variable>
#include <deque>
#include <functional>
#include <iostream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {
// Blocking repository work stays off Drogon's I/O loop. Two workers and a
// bounded queue match the two runtime DB connections; no unbounded fan-out.
class Workers {
 public:
    Workers() {
        for (int i=0; i<2; ++i) workers_.emplace_back([this] {
            for (;;) {
                std::function<void()> task;
                {
                    std::unique_lock lock(mutex_);
                    available_.wait(lock,[this]{return stopped_ || !queue_.empty();});
                    if (stopped_ && queue_.empty()) return;
                    task=std::move(queue_.front()); queue_.pop_front();
                }
                task();
            }
        });
    }
    ~Workers() {
        { std::lock_guard lock(mutex_); stopped_=true; }
        available_.notify_all();
        for (auto &worker:workers_) worker.join();
    }
    bool submit(std::function<void()> task) {
        std::lock_guard lock(mutex_);
        if (stopped_ || queue_.size()>=64) return false;
        queue_.push_back(std::move(task)); available_.notify_one(); return true;
    }
 private:
    bool stopped_=false;
    std::mutex mutex_;
    std::condition_variable available_;
    std::deque<std::function<void()>> queue_;
    std::vector<std::thread> workers_;
};
using Callback=std::function<void(const drogon::HttpResponsePtr &)>;

drogon::HttpResponsePtr error(const int status,const std::string &code,const std::string &message) {
    Json::Value body;
    body["code"]=code; body["message"]=message;
    body["request_id"]=drogon::utils::getUuid(); body["retryable"]=(status==503);
    auto response=drogon::HttpResponse::newHttpJsonResponse(body);
    response->setStatusCode(static_cast<drogon::HttpStatusCode>(status));
    response->addHeader("Cache-Control","no-store");
    return response;
}
std::string token(const drogon::HttpRequestPtr &request) {
    const auto header=request->getHeader("authorization");
    if (!header.starts_with("Bearer ")) throw madalasa::ApiError(401,"AUTHENTICATION_REQUIRED","Parent session required");
    return header.substr(7);
}
int limit(const drogon::HttpRequestPtr &request) {
    const auto text=request->getParameter("limit");
    if (text.empty()) return 25;
    int value=0;
    const auto [end,code]=std::from_chars(text.data(),text.data()+text.size(),value);
    if (code!=std::errc{} || end!=text.data()+text.size() || value<1 || value>100)
        throw madalasa::ApiError(400,"INVALID_REQUEST","Invalid pagination");
    return value;
}
void dispatch(Workers &workers,const Callback &callback,std::function<Json::Value()> task) {
    const auto job=[callback,task=std::move(task)] {
        try {
            auto response=drogon::HttpResponse::newHttpJsonResponse(task());
            response->addHeader("Cache-Control","no-store"); callback(response);
        } catch (const madalasa::ApiError &e) { callback(error(e.status,e.code,e.what())); }
        catch (const std::exception &) { callback(error(503,"DATABASE_UNAVAILABLE","Database operation unavailable")); }
    };
    if (!workers.submit(job)) callback(error(503,"BACKPRESSURE","Request queue full; retry later"));
}
}

int main() {
    try {
        trantor::Logger::setLogLevel(trantor::Logger::kWarn);
        // The harness may pin the single expected principal. A request still
        // cannot select one; validate the pin before any database work.
        const char *expected=std::getenv("MA_LOCAL_DB_PROBE_EXPECTED_PRINCIPAL");
        const std::string pinned=(expected && *expected) ? expected : "";
        if (!pinned.empty() && !madalasa::validUuid(pinned)) {
            std::cerr<<"Opt-in local probe refused: MA_LOCAL_DB_PROBE_EXPECTED_PRINCIPAL must be a UUID\n";
            return 78;
        }
        madalasa::Database database(madalasa::connectionInfoFromEnvironment());
        if (!pinned.empty()) database.expectPrincipal(pinned);
        Workers workers;
        auto &app=drogon::app();
        app.setThreadNum(1).setClientMaxBodySize(65536).addListener("127.0.0.1",18080);
        app.registerHandler("/v1/parents/me",[&](const drogon::HttpRequestPtr &req,Callback &&cb) {
            dispatch(workers,cb,[&,req]{return database.profile(token(req));});
        },{drogon::Get});
        app.registerHandler("/v1/children/{1}",[&](const drogon::HttpRequestPtr &req,Callback &&cb,std::string id) {
            dispatch(workers,cb,[&,req,id=std::move(id)]{return database.child(token(req),id);});
        },{drogon::Get});
        app.registerHandler("/v1/families/{1}/children",[&](const drogon::HttpRequestPtr &req,Callback &&cb,std::string id) {
            dispatch(workers,cb,[&,req,id=std::move(id)]{return database.children(token(req),id,req->getParameter("cursor"),limit(req));});
        },{drogon::Get});
        app.registerHandler("/v1/children/{1}/consents",[&](const drogon::HttpRequestPtr &req,Callback &&cb,std::string id) {
            dispatch(workers,cb,[&,req,id=std::move(id)]{return database.consents(token(req),id,req->getParameter("cursor"),limit(req));});
        },{drogon::Get});
        std::cout<<"Local database-backed API listening on 127.0.0.1:18080\n";
        app.run();
    } catch (const std::exception &) {
        std::cerr<<"Backend startup failed: check local database availability and restricted runtime configuration\n";
        return 1;
    }
}
