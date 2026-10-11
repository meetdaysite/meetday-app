# Hub Partner Feature Parity: Website vs Mobile

**October 11 implementation update:** The current post-pull Hub listing, role, interest, notification, proposal and deal/report fixes are documented in the root `SPACE_FEATURE_PARITY.md`. The sections below are historical pre-pull notes; the current dock is Proposals/Explore/Chats/Deals/Support, not a More-menu shell. Latest local checks: 29 Flutter tests pass, listing DTO validates with zero errors, and debug APK builds. Full live/device QA is still pending.

**Audit date:** 2026-10-08

**Scope:** Meetday Space Partner (Hub) portal in `frontend/src/app/spaces/` compared with the Flutter app in `meetday-app/`.

## Summary

Hub Partner login, signup, onboarding, and a dedicated mobile dashboard are connected. The mobile shell now exposes the major website destinations through its bottom navigation and More menu, with connected proposal, community-interest, deal, notification, profile, listing, preview, and support flows. Some website showcase and detailed community views remain simplified.

**Overall:** all primary website tabs have a mobile destination; detailed workflow parity remains partial in selected areas.

## Feature Matrix

| Website feature / route | Website behavior | Mobile counterpart | Status |
|---|---|---|---|
| Hub login and signup | Google authentication, registration, and Space Partner onboarding | Hub-specific Google login/signup consent; onboarding collects name, business, operating cities, and phone, then registers `accountType: SPACE` | Core flow implemented |
| Dashboard `/spaces/dashboard` | Welcome summary, proposals, campaigns, communities, active chats, locked deals | Dedicated `SpaceDashboardScreen`; loads `/spaces/me`, shows proposal/campaign/collaboration/deal counts, recent proposals, and navigates to campaigns/chats | Core overview implemented; community list and full deal actions are absent from the home |
| Campaign discovery `/spaces/dashboard/campaigns` | Browse published brand campaigns and express interest as a Space Partner | `CampaignsScreen`; interest requests use the `SPACE` role and route through the chat request workflow | Core flow implemented |
| Proposals `/spaces/dashboard/proposals` | Create/edit Space sponsorship proposals; list status and submit for review; offers are configured on the Hub listing | Space proposal list uses `actorType: SPACE`; shared form supports Space create/edit/submit, approval state, image and AI workflows | Core workflow implemented; website extras differ |
| Community discovery `/spaces/dashboard/communities` | Browse communities, inspect profiles and start collaboration | Lists approved communities and sends interest through `/space-host/communities/:hostProfileId/interest`; opens Chats | Core browse/interest implemented; detailed profile/gallery view is simplified |
| Chats `/spaces/dashboard/chats` | Manage accepted Hub/brand/community conversations | Unified `CommunityChatHubScreen` supports Space roles, messages, requests, deal terms, and report actions | Core chat workflow implemented; shared screen rather than a dedicated Hub page |
| Sponsorship chats `/spaces/dashboard/sponsorship-chats` | Review incoming/outgoing sponsorship and Hub requests | Included in the unified mobile chat hub and Space chat provider | Core workflow implemented; no separate route |
| Deals and reports `/spaces/dashboard/deals` | Review locked Hub deal terms and submit completion reports | Dedicated list filters locked Space threads and opens the unified chat for terms/report actions | Core list-to-chat workflow implemented |
| Profile `/spaces/dashboard/profile` | Edit Space account and public Hub listing | Account fields edit through `/spaces/me`; public listing editor supports required fields, logo, categories and Popup/Branding offers | Core fields implemented; showcase/past-event/brand/social editors remain partial |
| Profile preview `/spaces/dashboard/profile/preview` | Preview the public Hub listing | Read-only mobile listing preview is available from My Profile | Core preview implemented; content/layout depth differs |
| Notifications `/spaces/dashboard/notifications` | View notifications, mark read/all read and route chat alerts | Mobile list supports individual/all read and opens related Hub chats when metadata has a thread | Core workflow implemented |
| Support `/spaces/dashboard/support` | Contact Meetday support | Dedicated Hub shell opens the shared Support Chat screen; failed message loads show a retry action | Core entry and recovery UI implemented |

## Mobile Navigation and Data

- `HomeShell` routes `AccountRole.space` to `SpaceDashboardScreen`; Community and Brand continue using the shared dashboard.
- The dashboard profile greeting and operating-city chips load from `GET /spaces/me`.
- Proposal summaries use the existing `/sponsorships/me?actorType=SPACE` provider.
- Campaign summaries and discovery use published campaigns; campaign interest is submitted as `SPACE`.
- Active collaboration/unread summaries use the Space-aware chat hub, including Space chat threads and deal state.
- Bottom navigation exposes Dashboard, Campaigns, Chats, and Support. More exposes Proposals, Communities, Locked Deals, Notifications, and My Profile.

## Verification

- Widget test verifies a Space account opens the dedicated Hub dashboard and displays mocked profile, campaign-entry, and proposal data.
- Flutter test suite, focused analyzer checks, and Android debug build passed on 2026-10-08.
- No live signup or production write testing was performed; the app's default API environment is production-configured.

## Remaining Work

1. Complete public listing showcase-media, past-event, brand-history and social-link editing.
2. Expand community detail and gallery views to match the website.
3. Add standalone deal/report detail views; deal actions currently open the unified chat.