# Hub Partner Feature Parity: Website vs Mobile

**Audit date:** 2026-10-08

**Scope:** Meetday Space Partner (Hub) portal in `frontend/src/app/spaces/` compared with the Flutter app in `meetday-app/`.

## Summary

Hub Partner login, signup, onboarding, and a dedicated mobile dashboard are connected. The mobile home loads the Hub profile, displays live proposal/campaign/collaboration/deal summaries, and links into campaign discovery and the unified chat hub. The website still has a broader Space Partner workspace; profile editing, community discovery, dedicated deal/report pages, support, and notifications are not all exposed in the mobile Hub shell.

**Overall:** core entry and dashboard overview are implemented; portal parity remains partial.

## Feature Matrix

| Website feature / route | Website behavior | Mobile counterpart | Status |
|---|---|---|---|
| Hub login and signup | Google authentication, registration, and Space Partner onboarding | Hub-specific Google login/signup consent; onboarding collects name, business, operating cities, and phone, then registers `accountType: SPACE` | Core flow implemented |
| Dashboard `/spaces/dashboard` | Welcome summary, proposals, campaigns, communities, active chats, locked deals | Dedicated `SpaceDashboardScreen`; loads `/spaces/me`, shows proposal/campaign/collaboration/deal counts, recent proposals, and navigates to campaigns/chats | Core overview implemented; community list and full deal actions are absent from the home |
| Campaign discovery `/spaces/dashboard/campaigns` | Browse published brand campaigns and express interest as a Space Partner | `CampaignsScreen`; interest requests use the `SPACE` role and route through the chat request workflow | Core flow implemented |
| Proposals `/spaces/dashboard/proposals` | Create/edit Space sponsorship proposals with Popup and Branding offers; list status and submit for review | Shared proposal provider can query with `actorType: SPACE`; the existing generic mobile form does not provide the website's Space-specific offer fields and still has Host-oriented requirements | Partial; create/edit parity is incomplete |
| Community discovery `/spaces/dashboard/communities` | Browse communities and start collaboration | No dedicated Communities destination in the Hub mobile shell | Not exposed in Hub shell |
| Chats `/spaces/dashboard/chats` | Manage accepted Hub/brand/community conversations | Unified `CommunityChatHubScreen` supports Space roles, messages, requests, deal terms, and report actions | Core chat workflow implemented; shared screen rather than a dedicated Hub page |
| Sponsorship chats `/spaces/dashboard/sponsorship-chats` | Review incoming/outgoing sponsorship and Hub requests | Included in the unified mobile chat hub and Space chat provider | Core workflow implemented; no separate route |
| Deals and reports `/spaces/dashboard/deals` | Review locked Hub deal terms and submit completion reports | Space deal/report actions are available from supported chat threads; the Hub shell has no dedicated deals list/detail page | Partial |
| Profile `/spaces/dashboard/profile` | Edit Space profile and Hub community listing | Signup collects initial business name/cities; dashboard reads `/spaces/me`; no dedicated Space profile editor is exposed | Partial; read-only in the Hub shell |
| Profile preview `/spaces/dashboard/profile/preview` | Preview the public Hub listing | No Space-specific mobile preview destination | Not exposed |
| Notifications `/spaces/dashboard/notifications` | View and manage Hub notifications | No notifications destination in the dedicated Hub shell | Not exposed |
| Support `/spaces/dashboard/support` | Contact Meetday support | Dedicated Hub shell opens the shared Support Chat screen; failed message loads show a retry action | Core entry and recovery UI implemented |

## Mobile Navigation and Data

- `HomeShell` routes `AccountRole.space` to `SpaceDashboardScreen`; Community and Brand continue using the shared dashboard.
- The dashboard profile greeting and operating-city chips load from `GET /spaces/me`.
- Proposal summaries use the existing `/sponsorships/me?actorType=SPACE` provider.
- Campaign summaries and discovery use published campaigns; campaign interest is submitted as `SPACE`.
- Active collaboration/unread summaries use the Space-aware chat hub, including Space chat threads and deal state.
- Bottom navigation exposes Dashboard, Campaigns, Chats, and Support. Profile/sign-out is currently limited to sign-out from this Hub shell.

## Verification

- Widget test verifies a Space account opens the dedicated Hub dashboard and displays mocked profile, campaign-entry, and proposal data.
- Flutter test suite, focused analyzer checks, and Android debug build passed on 2026-10-08.
- No live signup or production write testing was performed; the app's default API environment is production-configured.

## Remaining Work

1. Add a Space-specific proposal create/edit form matching Popup and Branding fields.
2. Add Space profile edit/preview and community discovery destinations.
3. Add dedicated Hub deal/report and notification destinations to the mobile shell.