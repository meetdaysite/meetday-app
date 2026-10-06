# Meetday Mobile App - Backend Endpoint Audit

Audit date: 2026-10-02  
Mobile client: `meetday-app` Flutter app  
Backend: `backend` NestJS API  
Scope: endpoints actually called from `meetday-app/lib/**/*.dart`, compared with current backend controllers. This documents the current state; it does not claim every mobile screen is fully integrated.

## Connection Configuration

- Default REST base URL: `https://meetday-backend-371293689986.asia-south1.run.app/api/v1` (`lib/config/environment.dart`).
- Default socket URL: same Cloud Run service without `/api/v1`.
- `lib/core/network/api_client.dart` attaches the Firebase ID token from secure storage on each Dio request.
- Backend JSON responses are generally wrapped as `{ success, data, timestamp }`.
- `ApiClient.getRequest/postRequest/putRequest` now unwrap the standard `data` envelope.
- `lib/data/network/api_client.dart` is a second, legacy client with no per-request secure-storage interceptor; no active feature call sites were found using it.

## Endpoint Results

Legend: **MATCH** = route/method exists; **MISMATCH** = mobile call does not match backend; **PARTIAL** = route exists but role, payload, or response parsing does not match; **MOCK** = mobile returns local/static data instead of backend data.

| Mobile feature | Mobile request | Backend contract | Result |
|---|---|---|---|
| Connection check | `GET /health` via `checkConnection()` | `GET /health` (backend excludes `health` from global `/api/v1` prefix) | **FIXED LOCALLY**: calls the unprefixed endpoint. |
| Sign-in/profile bootstrap | `GET /api/v1/auth/me` | `GET /api/v1/auth/me` | **MATCH**; Firebase bearer token required. |
| Google sign-in registration | `POST /api/v1/auth/register` | `POST /api/v1/auth/register` | **MATCH**; role-specific payload must satisfy registration DTO. |
| Host community profile | `GET /api/v1/hosts/community` | `GET /api/v1/hosts/community` | **MATCH** for HOST role. |
| Generic profile read | `GET /api/v1/profile` | No `/profile` controller; host uses `/hosts/me`, space partner uses `/spaces/me`, brand uses `/brands/me` | **MISMATCH**. |
| Generic profile update | `PUT /api/v1/profile` | Host: `PATCH /hosts/profile`; Space: `PATCH /spaces/me`; Brand: `PATCH /brands/me` | **MISMATCH**: both path and method are wrong. |
| Profile image upload | `POST /api/v1/profile/image` multipart | `POST /api/v1/storage/upload-url`, then `PUT` file bytes to returned signed GCS URL | **MISMATCH**: mobile uses a route/backend upload flow that does not exist. |
| Browse events | `GET /api/v1/events` | `GET /api/v1/events` returns `{ data: { events, total, page, limit } }` | **PARTIAL**: route exists, but `eventsProvider` casts the full envelope to `List<Event>`. |
| Event detail | `GET /api/v1/events/:id` | Public event: `GET /api/v1/events/:id/public`; host-owned event: `GET /api/v1/events/me/:id` | **MISMATCH**. |
| Event attendees | `GET /api/v1/events/:id/attendees` | `GET /api/v1/events/me/:id/attendees` | **MISMATCH**: missing `/me`. |
| Event statistics | `GET /api/v1/events/stats` | No global `/events/stats`; host summary is `GET /api/v1/hosts/me/dashboard`; check-in stats are `GET /api/v1/events/:id/check-in-stats` | **MISMATCH**. |
| Create event | `POST /api/v1/events` | `POST /api/v1/events` | **MATCH** for HOST; verify mobile body against `CreateEventDto`. |
| Update event | `PUT /api/v1/events/:id` | `PATCH /api/v1/events/:id` | **MISMATCH**: wrong method. |
| Published sponsorship proposals | `GET /api/v1/sponsorships/published` | Same; returns `{ data: { proposals, total } }` | **MATCH**; mobile explicitly unwraps the envelope. |
| Own sponsorship proposals | `GET /api/v1/sponsorships/me` | Same; Brand screen should pass `actorType=BRAND`, Host/Space use their profile type | **MATCH** when role/profile is correct. |
| Create sponsorship proposal | `POST /api/v1/sponsorships` | Same | **MATCH**; mobile must send `actorType` for the intended profile. |
| Proposal AI and attachments | `POST /sponsorships/copilot/generate-draft`, `POST /sponsorships/copilot/extract-document`, `POST /storage/upload-url` then signed `PUT` | Same routes; proposal documents use `SPONSORSHIP_DOCUMENT`, cover images use `SPONSORSHIP_MEDIA` | **FIXED LOCALLY**: proposal form supports AI context extraction and PDF/document uploads with metadata. |
| Submit sponsorship proposal | Mobile: `PATCH /api/v1/sponsorships/:id/submit` | Backend: `PATCH /api/v1/sponsorships/:id/submit` | **FIXED LOCALLY** in proposal creation and dashboard actions. |
| Brand campaign list | `GET /api/v1/campaigns` | `GET /api/v1/campaigns` lists the caller Brand's own campaigns; discovery for hosts/brands is `GET /api/v1/campaigns/published` | **PARTIAL**: community campaign provider uses the Brand-owned list path and expects a bare list. |
| Apply to campaign | `POST /api/v1/campaigns/:id/apply` | `POST /api/v1/campaigns/published/:id/interest` (HOST role) | **MISMATCH**. |
| Browse community hubs | `GET /api/v1/spaces/community/browse` | Same; HOST and BRAND roles | **MATCH**. |
| List/create spaces | `GET /api/v1/spaces`, `POST /api/v1/spaces` | No root `/spaces` list/create routes. Owner profile is `/spaces/me`; public community-space listing is `/spaces/community/browse`; activation is `POST /spaces/community` | **MISMATCH** in `campaign_provider.dart`. |
| Payout list | `GET /api/v1/payouts` | `GET /api/v1/host/payouts` (HOST role) | **MISMATCH**. |
| Request payout withdrawal | `POST /api/v1/payouts/withdraw` | No matching self-service withdrawal route found | **MISMATCH / unsupported backend operation**. |
| Conversations list | `GET /api/v1/conversations` | No `/conversations` route. Chats use feature routes such as `/sponsorships/chats`, `/spaces/chats`, `/space-host/chats`, and collaboration chat endpoints | **MISMATCH**. |
| Analytics | `GET/POST /api/v1/analytics/*` | No general `/analytics` controller/routes found. Host dashboard summary is `/hosts/me/dashboard`; community analytics are scoped to a community route | **MISMATCH**. |
| Sponsorship chats/messages/deals | `/sponsorships/chats...` | Matching sponsorship controller routes | **MATCH**; role/query parameters still determine the participant context. |
| Space chats/deals | `/spaces/chats...` | Matching Spaces controller routes | **MATCH**; use `role=COMMUNITY`/`SPACE` as appropriate. |
| Space-Community partnership chats | `/space-host/chats...` | Matching Space Host Interest controller routes | **MATCH**. |
| Community collaboration chats | `/community-collaboration/chats...` | Matching Community Collaboration controller routes | **MATCH**. |
| Brand-Community chats | `/brand-community-collaboration/chats...` | Matching Brand Community Collaboration controller routes | **MATCH**; `asRole` selects Brand/Community context. |
| Meetday support chat | `/meetday-chat/messages` and message edit/delete | Matching Meetday Chat controller routes | **MATCH**; context query is supported. |
| Notifications | `GET /api/v1/notifications`; unread item taps use `PATCH /api/v1/notifications/:id/read` | Same routes | **FIXED LOCALLY**: dashboard renders backend data and marks items read. |
| Dashboard role profile | Brand `/brands/me`, Space `/spaces/me`, Host `/hosts/community` | Same role-specific endpoints | **FIXED LOCALLY**: dashboard shell selects by authenticated role. |
| Dashboard proposal list | `/sponsorships/me?actorType=BRAND/HOST/SPACE` | Same owner endpoint; `actorType` resolves the correct profile | **FIXED LOCALLY**: proposal tab loads owned proposals; published discovery remains separate. |
| Dashboard chats | `/sponsorships/chats` with role `BRAND` or `HOST` | Same endpoint with participant role | **FIXED LOCALLY** for sponsorship lists and message ownership. |
| Communities and Hubs tabs | `/sponsorships/communities`, `/spaces/community/browse` | Same browse endpoints | **FIXED LOCALLY**: removed demo fallback records. |

## Remaining Confirmed Blockers

1. Legacy `events_provider.dart`, `campaign_provider.dart`, `profile_provider.dart`, and `analytics_provider.dart` still contain route or parsing mismatches. Their corresponding standalone prototype screens are not currently wired into the active dashboard.
2. The Spaces role still receives the shared Community dashboard layout; only its profile fetch is role-specific so far.
3. Authenticated end-to-end checks have not been run for Brand, Host, and Space accounts.

## Validation Notes

- `flutter test` passes after the local changes, but these tests do not exercise authenticated backend requests.
- `flutter analyze` reports existing Freezed model implementation errors in `event_model.dart` and `campaign_model.dart`, along with lint warnings. No new analyzer errors were reported in the changed files.
- Route matching above is a static comparison against the current backend controllers and mobile call sites; an authenticated end-to-end smoke test is still required for each role.
- Backend API base URL defaults to the `meetday-dev` Cloud Run service, which is also what the web deployment documentation configures.
