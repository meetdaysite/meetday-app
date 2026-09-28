# Meetday Neo-Brutalist Design System Rules

You are building the Meetday mobile application in Flutter.
You must strictly follow the Meetday Neo-Brutalist Design System across all UI components, screens, and features.

---

## 1. Typography & Fonts
* **Display & Headings**: `Bricolage Grotesque`
  * Weights: `600` (SemiBold), `700` (Bold), `800` (ExtraBold)
  * Usage: Page headers, category titles, hero text, section headlines.
* **Body, Labels & UI**: `Poppins`
  * Weights: `400` (Regular), `500` (Medium), `600` (SemiBold), `700` (Bold)
  * Fallbacks: `Inter`, `system-ui`, `sans-serif`
  * Usage: Body copy, button labels, list items, chat bubbles, metadata.

---

## 2. Brand & Semantic Color Palette

| Category | Token / Color Name | Hex Code | Flutter Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Primary Brand** | **Meetday Red** | `#EE2C2C` / `#EE2727` | `Color(0xFFEE2C2C)` | Main CTA, primary branding, unread badges |
| **Brand Dark** | **Red Hover / Pressed** | `#D12525` | `Color(0xFFD12525)` | Pressed buttons, active tab backgrounds |
| **Accent / Highlight**| **Meetday Yellow** | `#FFC940` | `Color(0xFFFFC940)` | Secondary buttons, pending pill badges, chips |
| **Border / Ink** | **Solid Black** | `#000000` / `#111111` | `Color(0xFF000000)` | Neo-brutalist outlines, hard drop shadows |
| **Canvas / Page** | **Warm White** | `#FFFDFC` | `Color(0xFFFFFDFC)` | Primary background color |
| **Surface Card** | **Pure White** | `#FFFFFF` | `Color(0xFFFFFFFF)` | Card backgrounds, chat inputs, modal dialogs |
| **Muted Surface** | **Warm Beige** | `#FFF8F3` | `Color(0xFFFFF8F3)` | Muted panels, filter bars |
| **Text Primary** | **Dark Charcoal** | `#111111` | `Color(0xFF111111)` | Primary text, titles |
| **Text Secondary** | **Muted Grey** | `#525252` | `Color(0xFF525252)` | Subtitles, time-ago, secondary details |
| **Text Muted** | **Light Grey** | `#737373` / `#A3A3A3` | `Color(0xFFA3A3A3)` | Placeholders, inactive icons |
| **Status Green** | **Success / Deal Closed** | `#10B981` | `Color(0xFF10B981)` | Active indicators, deal closed status |
| **Status Blue** | **Hubs / Info** | `#216BFF` | `Color(0xFF216BFF)` | Hubs category, verified badges |
| **Status Purple** | **Campaigns / Vibe** | `#7C3AED` | `Color(0xFF7C3AED)` | Campaign tags, creative partnerships |

---

## 3. Neo-Brutalist Visual Identity
* **Borders**: Crisp, high-contrast borders:
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
