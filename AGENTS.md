# Meetday Mobile App - Development Guidelines

## Meetday Neo-Brutalist Design System

When building or updating features, screens, or components in this repository, strictly adhere to the Meetday Neo-Brutalist Design System:

### 1. Typography & Fonts
* **Display & Headings**: `Bricolage Grotesque` (Weights: `600` SemiBold, `700` Bold, `800` ExtraBold)
* **Body, Labels & UI**: `Poppins` (Weights: `400` Regular, `500` Medium, `600` SemiBold, `700` Bold)
* **Fallbacks**: `Inter`, `system-ui`, `sans-serif`

### 2. Color Tokens
* **Primary Brand (Meetday Red)**: `Color(0xFFEE2C2C)`
* **Brand Dark (Red Hover / Pressed)**: `Color(0xFFD12525)`
* **Accent / Highlight (Meetday Yellow)**: `Color(0xFFFFC940)`
* **Border / Ink (Solid Black)**: `Color(0xFF000000)`
* **Canvas / Page (Warm White)**: `Color(0xFFFFFDFC)`
* **Surface Card (Pure White)**: `Color(0xFFFFFFFF)`
* **Muted Surface (Warm Beige)**: `Color(0xFFFFF8F3)`
* **Text Primary (Dark Charcoal)**: `Color(0xFF111111)`
* **Text Secondary (Muted Grey)**: `Color(0xFF525252)`
* **Text Muted (Light Grey)**: `Color(0xFFA3A3A3)`
* **Status Green (Success / Deal Closed)**: `Color(0xFF10B981)`
* **Status Blue (Hubs / Info)**: `Color(0xFF216BFF)`
* **Status Purple (Campaigns / Vibe)**: `Color(0xFF7C3AED)`

### 3. Neo-Brutalist Component Rules
* **Borders**: 
  * Cards / Containers: `2.5px` or `3px` solid black (`Color(0xFF000000)`).
  * Chips / Pills / Badges: `1.5px` or `2px` solid black.
* **Hard Drop Shadows**: Solid black shadows with **0 blur radius**:
  * Large Cards / Modals: `Offset(4, 4)`, color `Color(0xFF000000)`, `blurRadius: 0`
  * Small Cards / Buttons: `Offset(2, 2)`, color `Color(0xFF000000)`, `blurRadius: 0`
  * Button Pressed state: `Offset(0, 0)` or `Offset(1, 1)` with `translate(2, 2)` (tactile click feel)
* **Corner Radii**:
  * Cards & Modals: `20.0` – `24.0`
  * Buttons & Inputs: `12.0` – `16.0`
  * Badges & Tags: `8.0` – `12.0`
  * Avatars / Circular Badges: `999.0` (Circle)
* **Badges**:
  * Notification unread badge: Red `Color(0xFFEE2C2C)` pill, bold white text, solid `1.5px` to `2px` border.
  * Pending request badge: Yellow `Color(0xFFFFC940)` pill, bold black text, solid black border.

Do NOT use generic Material 3 elevation, blur shadows, or pastel modern themes. Keep the bold, playful, high-contrast, black-bordered Meetday neo-brutalist aesthetic intact.
