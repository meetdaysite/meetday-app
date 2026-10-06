# Team Members Feature - Web vs Mobile Parity

## Web Frontend Implementation (TeamMembersModal.tsx)

### Features & Endpoints

| Feature | Endpoint | HTTP | Request | Response |
|---------|----------|------|---------|----------|
| **List Members** | `/hosts/community/members` | GET | - | `{ members: [], viewerCanManage, viewerIsOwner }` |
| **Invite Member** | `/hosts/community/members` | POST | `{ email }` | `{ id, name, email, role, status, canManageMembers }` |
| **Remove Member** | `/hosts/community/members/:id` | DELETE | - | void |
| **Set Permission** | `/hosts/community/members/:id/permission` | PATCH | `{ canManageMembers: boolean }` | void |

### Data Model

```typescript
interface TeamMember {
  id: string
  name: string | null          // "Pending signup" if null
  email: string
  role: "OWNER" | "MEMBER"
  status: "PENDING" | "ACTIVE"  // If PENDING = invite not yet accepted
  canManageMembers: boolean     // Can this member invite/remove others
}

interface TeamMembersList {
  members: TeamMember[]
  viewerCanManage: boolean      // Can current user invite/remove?
  viewerIsOwner: boolean        // Is current user the owner?
}
```

### UI Components & Features

#### 1. **Invite Form** (when viewerCanManage = true)
- Email input field with placeholder "teammate@example.com"
- "Invite" button (disabled during loading)
- Form validation (email required)
- Success toast: "Invite sent to X"
- Error handling with error toast
- List refreshes after successful invite

#### 2. **Member Card** (for each member)
- Avatar (initials or UserSvg icon)
- **Member Name** (or "Pending signup" if null)
- Email address
- **Role Badge** → "Owner" or "Member" (uppercase, small font)
- **Status Badge** → "Pending" (if status = PENDING, amber color)
- **Permission Toggle** (only if viewerIsOwner AND member.role = MEMBER)
  - Label: "Can add/remove members"
  - Switch toggles canManageMembers
  - Updates immediately when toggled
  - List refreshes after toggle
- **Delete Button** (only if viewerCanManage AND member.role = MEMBER)
  - Trash icon in circular button
  - Opens confirmation dialog on click

#### 3. **Remove Confirmation Dialog**
- Title: "Remove this member?"
- Message: "{email} will lose access to {accountLabel}'s dashboard immediately. If their invite is still pending, this email will no longer be able to join using the invite link."
- "Remove" button (destructive red)
- "Cancel" button
- Closes dialog on cancel
- Refreshes list after removal

#### 4. **Permission Rules**
- **viewerCanManage**: Can see invite form + can remove members
- **viewerIsOwner**: Can toggle permissions for members
- Owner cannot be removed
- Owner always shows "Owner" label (not a member)

#### 5. **Permissions Message**
- If NOT viewerCanManage: "You don't have permission to add members."

### Error Handling
- Toast messages for all errors (invite, remove, toggle)
- Uses `getApiErrorMessage(err)` for consistent error formatting

### UI States
1. **Loading**: "Loading members…"
2. **Empty**: "No members yet."
3. **Loaded**: Shows member list with actions

---

## Mobile App Current Status

### ✅ Implemented
- List members
- Invite form
- Remove members (basic)
- Endpoint integration via Riverpod providers

### ❌ Missing Features
1. **Member name display** - Shows only initials, not full name
2. **Role badge** - No OWNER/MEMBER indicator
3. **Status badge** - No PENDING status indicator
4. **Confirmation dialog** - Removes without confirmation
5. **Permission toggle** - Can't edit who can manage members
6. **Permission rules** - Not enforced properly
7. **Status/pending indication** - No visual for pending invites
8. **Better error messages** - Generic "Failed to X" messages
9. **Permission message** - Not showing if user can't manage

---

## Migration Plan (Priority)

### 🔴 HIGH - Core Functionality
1. Add **confirmation dialog for member removal** (ConfirmDialog)
2. Add **permission toggle** (`canManageMembers` switch)
3. Display **member name** from API response
4. Add **role badge** (OWNER/MEMBER)
5. Add **status badge** (PENDING)

### 🟡 MEDIUM - UX Improvements
1. Show "Can add/remove members" label on toggle
2. Improve error messages with formatted error details
3. Show permission denial message when viewerCanManage = false
4. Better loading state indicators

### 🟢 LOW - Polish
1. Add member avatar images (if available)
2. Animate status/role badges
3. Add empty member name handling ("Pending signup")

---

## Backend API Verification

All endpoints confirmed implemented:
- ✅ `GET /hosts/community/members` - [hosts.controller.ts:378](backend/src/modules/hosts/hosts.controller.ts#L378)
- ✅ `POST /hosts/community/members` - [hosts.controller.ts:387](backend/src/modules/hosts/hosts.controller.ts#L387)
- ✅ `DELETE /hosts/community/members/:id` - [hosts.controller.ts:400](backend/src/modules/hosts/hosts.controller.ts#L400)
- ✅ `PATCH /hosts/community/members/:id/permission` - [hosts.controller.ts:414](backend/src/modules/hosts/hosts.controller.ts#L414)

Response includes all fields needed.

---

## Next Steps

Update mobile `_TeamMembersSheet` to include:
1. Role badges
2. Status badges  
3. Member names (from response)
4. Permission toggle switch
5. Confirmation dialog for removal
6. Permission denial message
7. Better error formatting
