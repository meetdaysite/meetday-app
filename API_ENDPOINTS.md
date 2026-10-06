# Historical API Contract (Not Live)

> This file's examples below are an earlier mock API specification and do not match the current backend. Use [MOBILE_BACKEND_ENDPOINT_AUDIT.md](MOBILE_BACKEND_ENDPOINT_AUDIT.md) for the audited Flutter call sites, actual NestJS routes, and confirmed mismatches.

# Meetday Community App - API Endpoints

All endpoints should return JSON responses with proper error handling.

## Events Endpoints

### GET /api/v1/events
Fetch all community events
**Response:**
```json
[
  {
    "id": "event_1",
    "title": "Event Title",
    "description": "Event description",
    "date": "2024-10-12T10:00:00Z",
    "location": "City, Venue",
    "capacity": 200,
    "registered": 150,
    "price": 499.0,
    "status": "published",
    "imageUrl": ""
  }
]
```

### GET /api/v1/events/:id
Fetch single event details

### GET /api/v1/events/:id/attendees
Fetch attendees for an event
**Response:**
```json
[
  {
    "id": "attendee_1",
    "name": "John Doe",
    "email": "john@example.com",
    "status": "checked",
    "registrationDate": "2024-10-01T10:00:00Z",
    "phone": "+919876543210"
  }
]
```

### GET /api/v1/events/stats
Fetch overall event statistics
**Response:**
```json
{
  "totalEvents": 24,
  "totalAttendees": 5000,
  "checkedIn": 4200,
  "revenue": 850000.0,
  "averageAttendance": 78.5
}
```

### POST /api/v1/events
Create new event
**Body:**
```json
{
  "title": "Event Title",
  "description": "Description",
  "date": "2024-10-12T10:00:00Z",
  "location": "City, Venue",
  "capacity": 200,
  "price": 499.0
}
```

### PUT /api/v1/events/:id
Update event details

### DELETE /api/v1/events/:id
Delete/archive event

---

## Attendees Endpoints

### POST /api/v1/events/:id/attendees/checkin
Check-in attendee via QR code
**Body:**
```json
{
  "qrCode": "qr_code_value"
}
```

### POST /api/v1/attendees/export
Export attendee list as CSV/PDF
**Body:**
```json
{
  "eventId": "event_1",
  "format": "csv"
}
```

---

## Campaigns Endpoints

### GET /api/v1/campaigns
Fetch all active brand campaigns
**Response:**
```json
[
  {
    "id": "campaign_1",
    "brandName": "Brand Name",
    "title": "Campaign Title",
    "budget": 500000.0,
    "category": "Technology",
    "deadline": "2024-10-25T23:59:59Z",
    "status": "open",
    "description": "Campaign description"
  }
]
```

### POST /api/v1/campaigns/:id/apply
Apply to a brand campaign

### GET /api/v1/campaigns/:id
Fetch campaign details

---

## Spaces/Venues Endpoints

### GET /api/v1/spaces
Fetch all community spaces
**Response:**
```json
[
  {
    "id": "space_1",
    "name": "Space Name",
    "location": "City, Area",
    "capacity": 500,
    "status": "active",
    "totalBookings": 12,
    "amenities": ["WiFi", "Projector", "AC"]
  }
]
```

### POST /api/v1/spaces
Create new space
**Body:**
```json
{
  "name": "Space Name",
  "location": "City, Area",
  "capacity": 500,
  "amenities": ["WiFi", "Projector"]
}
```

### PUT /api/v1/spaces/:id
Update space details

### GET /api/v1/spaces/:id/bookings
Fetch space bookings

---

## Payouts Endpoints

### GET /api/v1/payouts
Fetch all payouts and revenue
**Response:**
```json
[
  {
    "id": "payout_1",
    "date": "2024-10-15T10:00:00Z",
    "dealName": "Deal Name",
    "amount": 180000.0,
    "status": "completed"
  }
]
```

### POST /api/v1/payouts/withdraw
Request withdrawal
**Body:**
```json
{
  "amount": 100000.0,
  "accountId": "account_1"
}
```

### GET /api/v1/payouts/summary
Get revenue summary
**Response:**
```json
{
  "totalEarnings": 875000.0,
  "thisMonth": 425000.0,
  "pending": 150000.0
}
```

---

## Messages/Conversations Endpoints

### GET /api/v1/conversations
Fetch all conversations
**Response:**
```json
[
  {
    "id": "conv_1",
    "participantId": "participant_1",
    "participantName": "Brand Name",
    "lastMessage": "Last message text",
    "lastMessageTime": "2024-10-20T10:00:00Z",
    "unreadCount": 2,
    "type": "brand"
  }
]
```

### GET /api/v1/conversations/:id/messages
Fetch messages in conversation

### POST /api/v1/conversations/:id/messages
Send message
**Body:**
```json
{
  "content": "Message content",
  "type": "text"
}
```

---

## Analytics Endpoints

### GET /api/v1/analytics
Fetch overall analytics
**Response:**
```json
{
  "totalMembers": 2450,
  "totalEvents": 24,
  "revenue": 450000.0,
  "deals": 18
}
```

### GET /api/v1/analytics/revenue
Fetch revenue breakdown
**Response:**
```json
{
  "sponsorship": 280000.0,
  "coCreated": 120000.0,
  "barter": 50000.0
}
```

### GET /api/v1/analytics/engagement
Fetch engagement metrics
**Response:**
```json
{
  "averageAttendanceRate": 78.0,
  "eventSatisfaction": 4.5,
  "memberGrowthRate": 8.5,
  "retentionRate": 85.0
}
```

### GET /api/v1/analytics/attendance?period=30days
Fetch attendance trend data

### POST /api/v1/analytics/export
Export analytics report
**Response:**
```json
{
  "url": "s3://bucket/report.pdf"
}
```

---

## Profile Endpoints

### GET /api/v1/profile
Fetch community profile
**Response:**
```json
{
  "id": "community_1",
  "name": "Community Name",
  "displayName": "Display Name",
  "email": "community@example.com",
  "phone": "+919876543210",
  "description": "Community description",
  "city": "Bangalore",
  "address": "123 Street, Area",
  "website": "www.example.com",
  "instagram": "@handle",
  "twitter": "@handle",
  "linkedin": "handle",
  "approvalStatus": "approved",
  "imageUrl": ""
}
```

### PUT /api/v1/profile
Update community profile
**Body:**
```json
{
  "name": "Community Name",
  "description": "Description",
  "city": "Bangalore"
}
```

### POST /api/v1/profile/image
Upload profile image

---

## Error Responses

All endpoints should return error responses in this format:
```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "statusCode": 400
}
```

Common status codes:
- 200: Success
- 201: Created
- 400: Bad Request
- 401: Unauthorized
- 403: Forbidden
- 404: Not Found
- 500: Server Error

---

## Authentication

All endpoints require Firebase ID token in Authorization header:
```
Authorization: Bearer <firebase_id_token>
```

Base URL: `http://localhost:8000/api/v1`
