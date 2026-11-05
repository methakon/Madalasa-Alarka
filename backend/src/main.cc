// Madalasa-Alarka M1 backend skeleton. Implements only the cross-cutting rules (request id, error envelope, health).
// Business routes are added against docs/openapi-m1.yaml in later changes. SYNTHETIC DATA ONLY.
#include <cstdlib>
#include <iostream>

#include <drogon/drogon.h>

#include "auth.h"
#include "db_support.h"
#include "device_activity.h"
#include "device_credentials.h"
#include "enrollment.h"
#include "families.h"
#include "children_read.h"
#include "parent_reads.h"
#include "device_capabilities.h"
#include "children_create.h"
#include "device_revoke.h"
#include "admin_session.h"
#include "admin_auth.h"
#include "admin_backoffice.h"
#include "admin_applicant.h"
#include "admin_owner.h"
#include "admin_faq_read.h"
#include "http_support.h"
#include "pairing.h"
#include "parent_session.h"
#include "billing_catalog.h"
#include "billing_trial.h"
#include "privacy_endpoints.h"
#include "privacy_request_endpoints.h"
#include "release_profile.h"
#include "free_location_reads.h"
#include "child_device_pairing_status.h"

namespace {
// Admin back-office routes (admin_auth.h, admin_backoffice.h). Authorization is SQL-side.
void registerAdminBackOffice() {
  using namespace drogon;
  app().registerHandler(
      "/v1/admin/auth/challenge",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_login_challenge(std::move(req)); },
      {Post});
  app().registerHandler(
      "/v1/admin/auth/google",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_login_google(std::move(req)); },
      {Post});
  app().registerHandler(
      "/v1/admin/auth/csrf",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_rotate_csrf(std::move(req)); },
      {Post});
  app().registerHandler(
      "/v1/admin/auth/session",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_logout(std::move(req)); },
      {Delete});
  app().registerHandler(
      "/v1/admin/access/profile",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_save_profile(std::move(req)); },
      {Put});
  app().registerHandler(
      "/v1/admin/access/requests",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_submit_request(std::move(req)); },
      {Post});
  app().registerHandler(
      "/v1/admin/owner/access-requests/{requestId}/decision",
      [](HttpRequestPtr req, std::string requestId) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_decide_request(std::move(req), std::move(requestId));
      },
      {Post});
  app().registerHandler(
      "/v1/admin/faqs",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_faq_draft(std::move(req), std::nullopt);
      },
      {Post});
  app().registerHandler(
      "/v1/admin/faqs/{faqId}",
      [](HttpRequestPtr req, std::string faqId) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_faq_draft(std::move(req), std::move(faqId));
      },
      {Put});
  app().registerHandler(
      "/v1/admin/faqs/{faqId}/publish",
      [](HttpRequestPtr req, std::string faqId) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_faq_publish(std::move(req), std::move(faqId));
      },
      {Post});
  app().registerHandler(
      "/v1/admin/support/tickets",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_list_tickets(std::move(req)); },
      {Get});
  app().registerHandler(
      "/v1/admin/support/tickets/{ticketId}/messages",
      [](HttpRequestPtr req, std::string ticketId) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_ticket_messages(std::move(req), std::move(ticketId));
      },
      {Get});
  app().registerHandler(
      "/v1/admin/support/tickets/{ticketId}/reply",
      [](HttpRequestPtr req, std::string ticketId) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_ticket_reply(std::move(req), std::move(ticketId));
      },
      {Post});
  app().registerHandler(
      "/v1/admin/subscribers",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_subscribers(std::move(req)); },
      {Get});
  app().registerHandler(
      "/v1/admin/usage/parents",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_parent_usage(std::move(req)); },
      {Get});
  app().registerHandler(
      "/v1/admin/security/audit",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::admin_security_audit(std::move(req)); },
      {Get});
}
}  // namespace

int main() {
  using namespace drogon;
  // Parse once before registering any listener/client. Bad limits cannot silently disable deadlines.
  try {
    (void)ma::db_limits();
  } catch (const std::invalid_argument&) {
    std::cerr << "invalid database limit configuration" << std::endl;
    return 78;
  }
  // Payment and 48h trial must stay inaccessible in the free-first release.
  const auto release_profile=ma::parse_release_profile(std::getenv("MA_RELEASE_PROFILE"));
  if(!release_profile) {
    std::cerr << "invalid MA_RELEASE_PROFILE: expected FREE_ONLY or PAID_VERIFIED" << std::endl;
    return 78;
  }
  if(*release_profile==ma::ReleaseProfile::PaidVerified &&
      !ma::paid_release_authorized(*release_profile,
        std::getenv("MA_OWNER_PAID_RELEASE_APPROVAL"),
        std::getenv("MA_BILLDESK_APPROVAL"),
        std::getenv("MA_PLAY_BILLING_APPROVAL"))) {
    std::cerr << "paid release blocked pending owner, provider and Play approval" << std::endl;
    return 78;
  }
  const auto release_caps=*release_profile==ma::ReleaseProfile::FreeOnly
      ? ma::free_release_capabilities() : ma::paid_release_capabilities();

  // Parent authentication mode: V2 opaque sessions unless the frozen M1 schema
  // is selected explicitly. Unknown values never fall back to a weaker mode.
  const auto parent_mode = ma::parse_parent_auth_mode(std::getenv("MA_PARENT_AUTH_MODE"));
  if (!parent_mode) {
    std::cerr << "invalid MA_PARENT_AUTH_MODE (v2_session or m1_direct_oidc)" << std::endl;
    return 78;
  }
  const auto session_ttl = ma::parse_parent_session_ttl(std::getenv("MA_PARENT_SESSION_TTL_SECONDS"));
  if (!session_ttl) {
    std::cerr << "invalid MA_PARENT_SESSION_TTL_SECONDS (300..43200)" << std::endl;
    return 78;
  }
  // Admin back office: exact browser Origin (scheme://host[:port]) gates login and
  // every admin mutation. Unset => admin login and writes are closed (503/403).
  const char* admin_origin = std::getenv("MA_ADMIN_ORIGIN");
  if (admin_origin && *admin_origin && !ma::valid_admin_origin(admin_origin)) {
    std::cerr << "invalid MA_ADMIN_ORIGIN (scheme://host[:port])" << std::endl;
    return 78;
  }
  const auto admin_ttl = ma::parse_admin_session_ttl(std::getenv("MA_ADMIN_SESSION_TTL_SECONDS"));
  if (!admin_ttl) {
    std::cerr << "invalid MA_ADMIN_SESSION_TTL_SECONDS (300..3600)" << std::endl;
    return 78;
  }
  const char* port_env = std::getenv("MA_LISTEN_PORT");
  const char* addr_env = std::getenv("MA_LISTEN_ADDR");
  const int port = port_env ? std::atoi(port_env) : 8080;
  const std::string addr = addr_env ? addr_env : "127.0.0.1";

  // Every request gets a fresh server-generated id before routing; every response carries it.
  app().registerPreRoutingAdvice([](const HttpRequestPtr& req, AdviceCallback&&, AdviceChainCallback&& next) {
    req->getAttributes()->insert(ma::kRequestIdAttr, ma::new_request_id());
    next();
  });
  app().registerPreSendingAdvice([](const HttpRequestPtr& req, const HttpResponsePtr& resp) {
    resp->removeHeader(ma::kRequestIdHeader);
    resp->addHeader(ma::kRequestIdHeader, ma::request_id_of(req));
  });

  // Liveness only: no database access, no data. Readiness is added with the database layer.
  app().registerHandler(
      "/healthz",
      [](const HttpRequestPtr&, std::function<void(const HttpResponsePtr&)>&& cb) {
        Json::Value j;
        j["status"] = "ok";
        cb(HttpResponse::newHttpJsonResponse(j));
      },
      {Get});

  // Readiness is separate from liveness: a missing/unusable database must never
  // be considered ready for guardian, enrollment, deletion or admin operations.
  // Expose only behind local operational checks; nginx must not proxy /readyz.
  app().registerHandler(
      "/readyz",
      [](HttpRequestPtr) -> Task<HttpResponsePtr> {
        Json::Value body(Json::objectValue);
        body["status"] = "not_ready";
        if (!app().hasDbClient(ma::kDbClientName) ||
            !app().hasDbClient(ma::kAuthDbClientName)) {
          auto resp = HttpResponse::newHttpJsonResponse(body);
          resp->setStatusCode(k503ServiceUnavailable);
          co_return resp;
        }
        auto db = app().getDbClient(ma::kDbClientName);
        auto issuer = app().getDbClient(ma::kAuthDbClientName);
        if (!db || !issuer) {
          auto resp = HttpResponse::newHttpJsonResponse(body);
          resp->setStatusCode(k503ServiceUnavailable);
          co_return resp;
        }
        try {
          // Read-only catalog probes on the actual handler logins: do not mint a
          // session, consume a challenge, bypass RLS or require migration-owner access.
          // Exact signatures come from the handlers and migrations 0020..0024/0030;
          // no unrelated migration-version floor is needed for this readiness gate.
          const auto res = co_await db->execSqlCoro(
              "SELECT session_user::text AS login, ("
              "NOT rolsuper AND NOT rolbypassrls "
              "AND pg_has_role(session_user,'ap_m1_api','MEMBER') "
              "AND NOT pg_has_role(session_user,'ap_auth_issuer','MEMBER') "
              "AND has_schema_privilege(current_user,'ap_m1','USAGE') "
              "AND to_regclass('ap_m1.devices') IS NOT NULL "
              "AND to_regclass('ap_m1.guardian_memberships') IS NOT NULL "
              "AND to_regclass('ap_m1.admin_accounts') IS NOT NULL "
              "AND (SELECT bool_and(COALESCE(has_function_privilege(current_user,"
              "to_regprocedure(signature),'EXECUTE'),false)) FROM (VALUES "
              "('ap_m1.ingest_location_batch_receipt(uuid,uuid,jsonb)'),"
              "('ap_m1.issue_device_pairing_code(uuid,bytea,integer)')"
              ") AS required(signature))) AS ready "
              "FROM pg_catalog.pg_roles WHERE rolname=current_user");
          const auto auth = co_await issuer->execSqlCoro(
              "SELECT session_user::text AS login, ("
              "NOT rolsuper AND NOT rolbypassrls "
              "AND pg_has_role(session_user,'ap_auth_issuer','MEMBER') "
              "AND NOT pg_has_role(session_user,'ap_m1_api','MEMBER') "
              "AND has_schema_privilege(current_user,'ap_m1','USAGE') "
              "AND (SELECT bool_and(COALESCE(has_function_privilege(current_user,"
              "to_regprocedure(signature),'EXECUTE'),false)) FROM (VALUES "
              "('ap_m1.exchange_parent_oidc_session(text,text,bytea,integer)'),"
              "('ap_m1.issue_admin_login_challenge()'),"
              "('ap_m1.exchange_admin_oidc_session(text,text,text,text,text,integer)'),"
              "('ap_m1.redeem_pairing_code(bytea,bytea,bytea,integer)'),"
              "('ap_m1.read_enrollment_challenge_expiry(uuid)'),"
              "('ap_m1.store_pending_device_profile(uuid,text,text,integer,text,text)'),"
              "('ap_m1.consume_enrollment_challenge(uuid)'),"
              "('ap_m1.activate_enrolled_device(uuid,bytea,integer)')"
              ") AS required(signature))) AS ready "
              "FROM pg_catalog.pg_roles WHERE rolname=current_user");
          const bool runtime_ready = res.size() == 1 && !res.at(0)["ready"].isNull() &&
                                     res.at(0)["ready"].as<bool>();
          const bool issuer_ready = auth.size() == 1 && !auth.at(0)["ready"].isNull() &&
                                    auth.at(0)["ready"].as<bool>() &&
                                    !res.empty() && !res.at(0)["login"].isNull() &&
                                    !auth.at(0)["login"].isNull() &&
                                    res.at(0)["login"].as<std::string>() != auth.at(0)["login"].as<std::string>();
          if (runtime_ready && issuer_ready) {
            body["status"] = "ready";
            co_return HttpResponse::newHttpJsonResponse(body);
          }
        } catch (const std::exception&) {
          // No database details, SQL or credentials in readiness response.
        }
        auto resp = HttpResponse::newHttpJsonResponse(body);
        resp->setStatusCode(k503ServiceUnavailable);
        co_return resp;
      },
      {Get});

  app().registerHandler(
      "/v1/release/capabilities",
      [release_caps](const HttpRequestPtr&,
                     std::function<void(const HttpResponsePtr&)>&& cb) {
        Json::Value body(Json::objectValue);
        body["release_profile"]=release_caps.paidEnabled?"PAID_VERIFIED":"FREE_ONLY";
        body["plan"]="FREE";
        body["free_location_tracking"]=true; // design entitlement; Android consent still required
        body["free_history_hours"]=release_caps.freeHistoryHours;
        body["moving_location_minutes_min"]=release_caps.movingLocationMinutesMin;
        body["moving_location_minutes_max"]=release_caps.movingLocationMinutesMax;
        body["paid_checkout_enabled"]=release_caps.paidEnabled;
        body["trial_enabled"]=release_caps.trialEnabled;
        body["premium_media_enabled"]=release_caps.premiumMediaEnabled;
        body["monitoring_approval_inferred"]=false;
        body["max_admitted_children"]=108;
        auto resp=HttpResponse::newHttpJsonResponse(body);
        ma::add_no_store(resp);cb(resp);
      },{Get});

  // Database: connection settings come from the environment; the role MUST be ap_m1_api (NOBYPASSRLS).
  if (const char* db = std::getenv("MA_PG_DB")) {
    auto env = [](const char* k, const char* d) { const char* v = std::getenv(k); return std::string(v ? v : d); };
    drogon::orm::PostgresConfig cfg;
    cfg.host = env("MA_PG_HOST", "127.0.0.1");
    cfg.port = static_cast<unsigned short>(ma::db_limits().port);
    cfg.databaseName = db;
    cfg.username = env("MA_PG_USER", "ap_m1_api");
    cfg.password = env("MA_PG_PASSWORD", "");
    cfg.connectionNumber = ma::db_limits().connections;
    cfg.name = ma::kDbClientName;
    cfg.isFast = false;
    cfg.characterSet = "";
    // v1.9.14 DbClientImpl bounds both queued transaction acquisition and SQL
    // execution with this value; each acquired Transaction inherits it.
    cfg.timeout = ma::db_limits().client_seconds();
    cfg.autoBatch = false;
    // v1.9.14 maps these to PostgreSQL startup -c options (not libpq keywords).
    // Server-side cancellation frees the connection even after a client timeout.
    cfg.connectOptions = {{"statement_timeout", std::to_string(ma::db_limits().statement_ms)},
                          {"lock_timeout", std::to_string(ma::db_limits().lock_ms)},
                          {"idle_in_transaction_session_timeout", "60000"}};
    app().addDbClient(cfg);
    // Session issuance uses a SEPARATE login (member of ap_auth_issuer only).
    // The runtime role can never mint sessions, so the two must differ.
    const char* auth_user = std::getenv("MA_PG_AUTH_USER");
    // Used by the parent session exchange (v2_session mode) and the admin login.
    if (auth_user && *auth_user) {
      if (std::string(auth_user) == cfg.username) {
        std::cerr << "MA_PG_AUTH_USER must differ from the runtime MA_PG_USER" << std::endl;
        return 78;
      }
      drogon::orm::PostgresConfig issuer = cfg;
      issuer.username = auth_user;
      issuer.password = env("MA_PG_AUTH_PASSWORD", "");
      issuer.connectionNumber = 2;
      issuer.name = ma::kAuthDbClientName;
      app().addDbClient(issuer);
    } else {
      LOG_WARN << "MA_PG_AUTH_USER not set: parent session exchange and admin login answer 503";
    }
  } else {
    LOG_WARN << "MA_PG_DB not set: routes that need the database answer 503";
  }

  ma::Authenticator authenticate;
  try {
    authenticate = ma::select_authenticator();
  } catch (const std::invalid_argument&) {
    std::cerr << "invalid Google OIDC client configuration" << std::endl;
    return 78;
  }
  const ma::ParentAuth parent{*parent_mode, authenticate};
  try {
    ma::admin_web_config() = ma::AdminWebConfig{admin_origin ? std::string(admin_origin) : std::string(),
                                                 *admin_ttl, ma::select_admin_verifier()};
  } catch (const std::invalid_argument&) {
    std::cerr << "invalid admin Google OIDC client configuration" << std::endl;
    return 78;
  }
  registerAdminBackOffice();
  if (*parent_mode == ma::ParentAuthMode::V2Session) {
    // Identity exchange: verified ID token in, server-generated opaque session out.
    app().registerHandler(
        "/v1/auth/parent/google",
        [parent, ttl = *session_ttl](HttpRequestPtr req) -> Task<HttpResponsePtr> {
          co_return co_await ma::exchange_parent_session(std::move(req), parent, ttl);
        },
        {Post});
    app().registerHandler(
        "/v1/auth/session",
        [parent](HttpRequestPtr req) -> Task<HttpResponsePtr> {
          co_return co_await ma::revoke_parent_session(std::move(req), parent);
        },
        {Delete});
  } else {
    LOG_WARN << "M1 direct ParentOIDC mode: frozen M1 schema only, no V2 sessions";
  }
  app().registerHandler(
      "/v1/faqs",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::read_faqs(std::move(req),false);
      },
      {Get});
  app().registerHandler(
      "/v1/admin/faqs",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::read_faqs(std::move(req),true);
      },
      {Get});
  app().registerHandler(
      "/v1/admin/faqs/{faqId}",
      [](HttpRequestPtr req,std::string faqId) -> Task<HttpResponsePtr> {
        co_return co_await ma::read_faqs(std::move(req),true,std::move(faqId));
      },
      {Get});

  app().registerHandler(
      "/v1/admin/owner/access-requests",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_owner_access_requests(std::move(req));
      },
      {Get});
  app().registerHandler(
      "/v1/admin/access/profile",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_applicant_self_read(std::move(req), false);
      },
      {Get});
  app().registerHandler(
      "/v1/admin/access/requests/me",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_applicant_self_read(std::move(req), true);
      },
      {Get});

  // Separate admin session (cookie) from ParentOIDC; no anonymous role access.
  app().registerHandler(
      "/v1/admin/access/me",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::admin_access_me(std::move(req));
      },
      {Get});

  app().registerHandler(
      "/v1/families",
      [parent](HttpRequestPtr req) -> Task<HttpResponsePtr> { co_return co_await ma::create_family(std::move(req), parent); },
      {Post});

  app().registerHandler(
      "/v1/families",
      [parent](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::list_families(std::move(req), parent);
      },
      {Get});

  // Routes remain in source, but are not registered in free-only deployments.
  if(release_caps.paidEnabled) {
  // L10-005: product catalog; prices are never quoted until Play metadata is verified.
  app().registerHandler(
      "/v1/billing/catalog",
      [parent](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::billing_catalog(std::move(req), parent);
      }, {Get});

  // L10-002: server-side 48h family trial (policy enforced in SQL).
  app().registerHandler(
      "/v1/families/{familyId}/trial/eligibility",
      [parent](HttpRequestPtr req, std::string familyId) -> Task<HttpResponsePtr> {
        co_return co_await ma::family_trial(std::move(req), std::move(familyId), parent, false);
      }, {Get});
  app().registerHandler(
      "/v1/families/{familyId}/trial/start",
      [parent](HttpRequestPtr req, std::string familyId) -> Task<HttpResponsePtr> {
        co_return co_await ma::family_trial(std::move(req), std::move(familyId), parent, true);
      }, {Post});

  }

  app().registerHandler(
      "/v1/children/{childId}/paired-device",
      [parent](HttpRequestPtr req,std::string childId)->Task<HttpResponsePtr>{
        co_return co_await ma::child_pairing_status(std::move(req),std::move(childId),parent);
      },{Get});
  app().registerHandler(
      "/v1/children/{childId}/location/latest",
      [parent](HttpRequestPtr req,std::string childId)->Task<HttpResponsePtr>{
        co_return co_await ma::free_location_read(std::move(req),std::move(childId),parent,false);
      },{Get});
  app().registerHandler(
      "/v1/children/{childId}/location/history",
      [parent](HttpRequestPtr req,std::string childId)->Task<HttpResponsePtr>{
        co_return co_await ma::free_location_read(std::move(req),std::move(childId),parent,true);
      },{Get});

  // Existing master OpenAPI: child-scoped privacy operations, server-enforced.
  app().registerHandler(
      "/v1/children/{childId}/guardian-grants",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::read_child_privacy(std::move(req), std::move(childId), parent,
                                                   ma::PrivacyReadKind::GuardianGrants);
      }, {Get});
  app().registerHandler(
      "/v1/children/{childId}/consents",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::read_child_privacy(std::move(req), std::move(childId), parent,
                                                   ma::PrivacyReadKind::Consents);
      }, {Get});
  app().registerHandler(
      "/v1/children/{childId}/guardian-grants/{grantId}",
      [parent](HttpRequestPtr req, std::string childId, std::string grantId) -> Task<HttpResponsePtr> {
        co_return co_await ma::delete_child_privacy_grant(std::move(req), std::move(childId),
                                                           std::move(grantId), parent);
      }, {Delete});
  // Phase 15: SQL-authorized erasure/export jobs with truthful pending status.
  app().registerHandler(
      "/v1/children/{childId}/erasure-requests",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::child_privacy_job(std::move(req),std::move(childId),parent,true,true);
      }, {Post});
  app().registerHandler(
      "/v1/children/{childId}/erasure-requests",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::child_privacy_job(std::move(req),std::move(childId),parent,true,false);
      }, {Get});
  app().registerHandler(
      "/v1/children/{childId}/export-requests",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::child_privacy_job(std::move(req),std::move(childId),parent,false,true);
      }, {Post});
  app().registerHandler(
      "/v1/children/{childId}/export-requests",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::child_privacy_job(std::move(req),std::move(childId),parent,false,false);
      }, {Get});

  app().registerHandler(
      "/v1/devices/{deviceId}/consent-status",
      [](HttpRequestPtr req, std::string deviceId) -> Task<HttpResponsePtr> {
        co_return co_await ma::device_consent_status(std::move(req), std::move(deviceId));
      }, {Get});

  app().registerHandler(
      "/v1/children/{childId}",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::get_child(std::move(req), std::move(childId), parent);
      },
      {Get});

  app().registerHandler(
      "/v1/children/{childId}/devices",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::list_child_devices(std::move(req), std::move(childId), parent);
      },
      {Get});

  app().registerHandler(
      "/v1/families/{familyId}/children",
      [parent](HttpRequestPtr req, std::string familyId) -> Task<HttpResponsePtr> {
        co_return co_await ma::create_child(std::move(req), std::move(familyId), parent);
      },
      {Post});

  app().registerHandler(
      "/v1/families/{familyId}/children",
      [parent](HttpRequestPtr req, std::string familyId) -> Task<HttpResponsePtr> {
        co_return co_await ma::list_children(std::move(req), std::move(familyId), parent);
      },
      {Get});

  app().registerHandler(
      "/v1/children/{childId}/pairing-codes",
      [parent](HttpRequestPtr req, std::string childId) -> Task<HttpResponsePtr> {
        co_return co_await ma::issue_pairing_code(std::move(req), std::move(childId), parent);
      },
      {Post});

  app().registerHandler(
      "/v1/enrollment",
      [](HttpRequestPtr req) -> Task<HttpResponsePtr> {
        co_return co_await ma::redeem_enrollment(std::move(req));
      },
      {Post});

  app().registerHandler(
      "/v1/enrollment/{enrollmentId}/proof",
      [](HttpRequestPtr req, std::string enrollmentId) -> Task<HttpResponsePtr> {
        co_return co_await ma::complete_enrollment_proof(std::move(req), std::move(enrollmentId));
      },
      {Post});

  app().registerHandler(
      "/v1/devices/{deviceId}/pairing",
      [parent](HttpRequestPtr req, std::string deviceId) -> Task<HttpResponsePtr> {
        co_return co_await ma::revoke_device(std::move(req), std::move(deviceId), parent);
      },
      {Delete});

  app().registerHandler(
      "/v1/devices/{deviceId}/credential/challenge",
      [](HttpRequestPtr req, std::string deviceId) -> Task<HttpResponsePtr> {
        co_return co_await ma::request_credential_challenge(std::move(req), std::move(deviceId));
      },
      {Post});

  app().registerHandler(
      "/v1/devices/{deviceId}/credential/renew",
      [](HttpRequestPtr req, std::string deviceId) -> Task<HttpResponsePtr> {
        co_return co_await ma::renew_device_credential(std::move(req), std::move(deviceId));
      },
      {Post});

  app().registerHandler(
      "/v1/devices/{deviceId}/capabilities",
      [](HttpRequestPtr req, std::string deviceId) -> Task<HttpResponsePtr> {
        co_return co_await ma::record_capabilities(std::move(req), std::move(deviceId));
      },
      {Post});

  app().registerHandler(
      "/v1/devices/{deviceId}/health",
      [](HttpRequestPtr req, std::string deviceId) -> Task<HttpResponsePtr> {
        co_return co_await ma::record_device_health(std::move(req), std::move(deviceId));
      },
      {Post});

  app().registerHandler(
      "/v1/devices/{deviceId}/locations:batch",
      [](HttpRequestPtr req, std::string deviceId) -> Task<HttpResponsePtr> {
        co_return co_await ma::ingest_location_batch(std::move(req), std::move(deviceId));
      },
      {Post});

  // Unknown route or wrong method -> catalog format, never Drogon's HTML page.
  app().setDefaultHandler([](const HttpRequestPtr& req, std::function<void(const HttpResponsePtr&)>&& cb) {
    cb(ma::error_response("NOT_FOUND", "no such route", ma::request_id_of(req)));
  });
  app().setExceptionHandler([](const std::exception&, const HttpRequestPtr& req,
                               std::function<void(const HttpResponsePtr&)>&& cb) {
    // Never echo exception text: it may contain SQL or identifiers.
    cb(ma::error_response("INTERNAL_ERROR", "unexpected server error", ma::request_id_of(req)));
  });
  // Errors raised by the framework itself (oversize body, bad request line, ...) also use the catalog envelope and a
  // server-generated request id, so no Drogon-specific error page or header set can leak.
  app().setCustomErrorHandler([](HttpStatusCode code, const HttpRequestPtr& req) {
    const std::string rid = req ? ma::request_id_of(req) : ma::new_request_id();
    switch (code) {
      case k413RequestEntityTooLarge: return ma::error_response("PAYLOAD_TOO_LARGE", "request body too large", rid);
      case k400BadRequest: return ma::error_response("INVALID_REQUEST", "malformed request", rid);
      case k404NotFound:
      case k405MethodNotAllowed: return ma::error_response("NOT_FOUND", "no such route", rid);
      case k503ServiceUnavailable: return ma::error_response("SERVICE_UNAVAILABLE", "service unavailable", rid, true);
      default: return ma::error_response("INTERNAL_ERROR", "unexpected server error", rid);
    }
  });
  // The API limit is 64 KiB and handlers enforce it with a catalog-format 413. Drogon's own parser limit must be HIGHER:
  // its over-limit answer is a bare "413 ... Connection: close" written before any handler, advice or error hook runs,
  // so it has no JSON envelope and no X-Request-Id. Bodies over 1 MiB still get that bare 413; the reverse proxy should
  // cap the body at 64 KiB so clients never see it (docs/API_CONVENTIONS_AND_ERROR_CATALOG.md, G-7).
  app().setClientMaxBodySize(1024 * 1024);  // 413 PAYLOAD_TOO_LARGE is mapped in the body-size handler when routes exist

  app().addListener(addr, static_cast<uint16_t>(port));
  std::cout << "madalasa backend listening on " << addr << ":" << port << std::endl;
  app().run();
  return 0;
}
