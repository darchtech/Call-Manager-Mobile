# Call Manager Mobile – Project Overview

## 1. What Is This Project?

**Call Manager Mobile** (`call_navigator`) is a Flutter-based **mobile CRM (Customer Relationship Management)** application designed for sales teams who make outbound phone calls. It lets agents manage leads, track every call automatically, schedule follow-ups, and monitor tasks – all while staying in sync with a backend server even when the device is temporarily offline.

The app replaces the built-in Android dialer and hooks directly into the telephony stack, so every outgoing call is captured without requiring the agent to manually log anything.

---

## 2. Core Features

| Feature | Description |
|---|---|
| **Call Tracking** | Replaces the default Android dialer; captures call state (dialling → ringing → connected → ended) via a native `MethodChannel`. |
| **Lead Management** | Full CRUD for sales leads with status progression (e.g., *New → Follow Up → Converted*), search, filtering, and priority levels. |
| **Task Management** | Paginated task list with automatic completion-count recalculation whenever a related lead's call status changes. |
| **Follow-up Scheduling** | Agents can set a future follow-up date on any lead; the app schedules a local notification via `ReminderService`. |
| **Offline-First Sync** | All data is persisted locally in a Hive NoSQL database. Changes are synced to a REST backend when connectivity is restored. |
| **Push Notifications** | Firebase Cloud Messaging (FCM) delivers server-side push events to the device; `FCMService` handles token registration and incoming messages. |
| **Real-Time Updates** | A persistent WebSocket connection (`WebSocketService`) streams live events (new leads, task updates) from the backend. |
| **Authentication** | JWT-based login with automatic token refresh via `AuthService` and `ApiService`. |

---

## 3. Technology Stack

| Layer | Technology |
|---|---|
| **UI Framework** | Flutter (Dart) |
| **State Management** | GetX (`get: ^4.6.6`) – controllers, reactive observables, dependency injection |
| **Local Database** | Hive (`hive: ^2.2.3`, `hive_flutter`) – NoSQL key-value store with typed adapters |
| **HTTP Client** | Dio (`dio: ^5.7.0`) with interceptors for auth-token injection and refresh |
| **Push Notifications** | Firebase Cloud Messaging + `flutter_local_notifications` |
| **Real-Time** | `web_socket_channel` + `socket_io_client` |
| **Connectivity** | `connectivity_plus` |
| **Secure Storage** | `flutter_secure_storage` (JWT tokens) |
| **ID Generation** | `uuid` |
| **Code Generation** | `hive_generator` + `build_runner` (Hive type adapters) |

---

## 4. Project Architecture

The project follows a **Clean Architecture** pattern layered over **MVVM**, using GetX for dependency injection and state management.

```
┌──────────────────────────────────────────┐
│           Presentation Layer             │
│  Screens (View)  ←→  Widgets             │
│  lib/view/         lib/widgets/          │
└────────────────────┬─────────────────────┘
                     │ Observes RxObservables
                     │ Calls controller methods
┌────────────────────▼─────────────────────┐
│         State Management Layer           │
│   GetX Controllers  (lib/controller/)    │
│  AppController  LeadController           │
│  CallController  TaskController          │
└────────────────────┬─────────────────────┘
                     │ Calls service methods
┌────────────────────▼─────────────────────┐
│          Business Logic Layer            │
│        Services  (lib/services/)         │
│  ApiService  AuthService  NetworkService │
│  LeadSyncService  CallSyncService        │
│  TaskService  TaskSyncService            │
│  FCMService  ReminderService             │
│  WebSocketService  FollowUpService       │
└───────────┬──────────────────────────────┘
            │ Reads / writes
┌───────────▼──────────────────────────────┐
│            Data Layer                    │
│  Repositories  (lib/repository/)         │
│  LeadRepository  TaskRepository          │
│  CallRepository  FollowUpRepository      │
│  ── Hive NoSQL Local DB ──               │
│  CallDatabaseService (lib/services/)     │
└──────────────────────────────────────────┘
            │ Syncs when online
┌───────────▼──────────────────────────────┐
│          Backend / External              │
│  REST API (Dio/ApiService)               │
│  WebSocket Server                        │
│  Firebase (FCM)                          │
└──────────────────────────────────────────┘
```

### Key Architectural Decisions

* **Offline-First** – Every write goes to Hive first; background sync services (`LeadSyncService`, `CallSyncService`, `TaskSyncService`) upload pending changes when the network is available.
* **Reactive UI** – Controllers expose `RxList<T>`, `RxString`, `RxBool` observables; widgets wrapped in `Obx()` rebuild automatically on changes.
* **Dependency Injection** – `Get.put()` registers singletons at startup; `Bindings` lazily inject controllers when a route is activated.
* **Native Integration** – The app registers two `MethodChannel`s (`call_tracking_nav`, `dialer_role`) to communicate with the Android telephony layer.

---

## 5. Directory Structure

```
lib/
├── main.dart                    # App entry point; DI setup, Hive init
├── binding/                     # GetX Bindings (lazy DI per route)
│   ├── app_binding.dart
│   ├── call_binding.dart
│   ├── lead_binding.dart
│   └── task_binding.dart
├── controller/                  # GetX Controllers (state + business logic)
│   ├── app_controller.dart      # Routing / initial route determination
│   ├── call_controller.dart     # Live call tracking, call record management
│   ├── lead_controller.dart     # Lead CRUD, search, filter, statistics
│   └── task_controller.dart     # Task list, pagination, completion counting
├── model/                       # Data models (Hive-serializable)
│   ├── call_record.dart         # Detailed per-call log entry
│   ├── call_status.dart         # Simple enum: idle/ringing/connected/ended
│   ├── follow_up.dart           # Follow-up appointment with resolution metadata
│   ├── lead.dart                # Sales lead with call & sync tracking
│   ├── pagination_response.dart # Generic paginated API response wrapper
│   └── task.dart                # Task with optional lead linkage & progress
├── repository/                  # Hive data access layer
│   ├── call_repository.dart
│   ├── follow_up_repository.dart
│   ├── lead_repository.dart
│   └── task_repository.dart
├── routes/                      # Named route definitions & page map
│   ├── app_pages.dart
│   └── routes.dart
├── services/                    # Business logic & external integrations
│   ├── api_service.dart         # Dio HTTP client with auth interceptors
│   ├── auth_service.dart        # Login/logout, JWT, FCM token sync
│   ├── call_database_service.dart # Hive init for call records
│   ├── call_sync_service.dart   # Sync call records to backend
│   ├── data_seeding_service.dart# Dev utility: seed sample data
│   ├── fcm_service.dart         # Firebase Cloud Messaging
│   ├── follow_up_service.dart   # Follow-up CRUD with API + Hive
│   ├── lead_sync_service.dart   # Sync lead changes; fetch status options
│   ├── network_service.dart     # Connectivity monitoring + offline queue
│   ├── offline_sync_manager.dart# Orchestrates sync when going online
│   ├── reminder_service.dart    # Local notifications for follow-up reminders
│   ├── task_service.dart        # Task CRUD with pagination
│   ├── task_sync_service.dart   # Sync tasks to backend
│   └── websocket_service.dart   # Persistent WebSocket / Socket.IO connection
├── utils/                       # App-wide constants and helpers
│   ├── app_colors.dart / app_colors_new.dart
│   ├── config.dart              # Base URL, app name, environment constants
│   ├── date_utils.dart          # Date formatting helpers (IST-aware)
│   ├── dialer_role.dart         # Native dialer role helper
│   ├── font_utils.dart
│   ├── text_helper.dart / text_styles.dart / text_styles_new.dart
│   └── theme_config.dart        # Material light/dark theme configuration
├── view/                        # UI Screens
│   ├── login_screen.dart
│   ├── call_screen.dart         # Current call / dialler UI
│   ├── after_call_screen.dart   # Active call overlay
│   ├── call_records_screen.dart # Historical call log
│   ├── lead_screen.dart         # Lead list with search & filters
│   ├── lead_detail_screen.dart  # Lead detail & edit form
│   ├── follow_up_screen.dart    # Follow-up list for a lead
│   ├── task_screen.dart         # Paginated task list
│   ├── task_detail_screen.dart  # Task detail view
│   ├── reminder_screen.dart     # Reminder management
│   └── websocket_test_screen.dart # Developer diagnostic screen
└── widgets/                     # Shared/reusable UI components
    ├── base_scaffold.dart        # Common scaffold with drawer
    ├── global_drawer.dart        # Navigation drawer
    ├── follow_up_dialog.dart     # Create follow-up dialog
    ├── edit_follow_up_dialog.dart
    ├── reminder_dialog.dart      # Schedule reminder dialog
    ├── toastification.dart       # Toast notification helper
    └── websocket_status_widget.dart
```

---

## 6. Data Models

### Lead
The central entity. Represents a sales prospect with full contact information, current lead status (e.g., *New*, *Follow Up*, *Converted*), detailed call status, reminder settings, and sync metadata.

**Call-status categories** (derived from granular statuses):
* `CONTACTED` – call was answered and conversation took place
* `NO ANSWER` – rang but was not picked up, or busy
* `CALLED` – dialler initiated but hung up before answer
* `NOT CONTACTED` – declined or never attempted

### CallRecord
Captures a single phone call event: phone number, contact name, timestamps (initiated, connected, ended), calculated duration, outcome status, source (`app` / `system`), and sync metadata.

### Task
A work item optionally linked to one or more leads. Tracks status (`open`, `inProgress`, `done`), priority, due date, and progress counters (`completedCount` / `totalCount`) that are recalculated automatically when related leads receive call outcomes.

### FollowUp
A scheduled follow-up appointment for a lead with a due date, optional note, status (`PENDING`, `DONE`, `CANCELLED`), and resolution metadata stored in a flexible `Map` field.

### LeadStatus
A configurable status option fetched from the backend, allowing administrators to customise the lead-status and call-status dropdowns without a client update.

---

## 7. Key Data Flows

### 7.1 Outbound Call Tracking
```
User taps "Call" in app
  └─► CallController.startCallForLead()
        └─► url_launcher opens dialler
              └─► Android telephony fires call-state events
                    └─► MethodChannel → CallController.onCallStateChanged()
                          ├─► CallRecord created / updated in Hive
                          ├─► Lead.callStatus updated in Hive
                          ├─► TaskController.recalculateTaskCompletionForLead()
                          └─► CallSyncService queues record for upload
```

### 7.2 Lead Sync (Offline → Online)
```
Lead created / updated locally (Hive, isSynced = false)
  └─► LeadSyncService (periodic, every 5 min)
        └─► NetworkService.isConnected?
              ├─► Yes → ApiService.createLead() / updateLead()
              │         └─► Lead.markSynced() → isSynced = true
              └─► No  → queued until connectivity restored
```

### 7.3 Authentication & Token Refresh
```
User logs in → AuthService.login()
  └─► ApiService.post('/auth/login')
        └─► Tokens stored in flutter_secure_storage
              └─► ApiService interceptor attaches Bearer token on every request
                    └─► On 401 → AuthService.refreshToken()
                          └─► On failure → AuthService.logout() → /login
```

### 7.4 Push Notification (FCM)
```
Backend sends FCM notification
  └─► FCMService.onMessage / onBackgroundMessage
        └─► flutter_local_notifications displays local notification
              └─► User taps → FCMService routes to relevant screen
```

---

## 8. Navigation & Routing

GetX named routes are defined in `routes/routes.dart` and mapped to pages in `routes/app_pages.dart`. The initial route is determined by `AppController.getInitialRoute()`:

* If authenticated → `/leads`
* Otherwise → `/login`

A native Android `MethodChannel` (`call_tracking_nav`) can trigger navigation from the telephony layer, e.g., opening the lead detail screen immediately after a call ends.

---

## 9. Getting Started

### Prerequisites
* Flutter SDK `^3.8.1`
* Android SDK (API 21+)
* A running backend server (see backend repo)
* Firebase project with Android app configured

### Setup
```bash
flutter clean
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Configuration
Edit `lib/utils/config.dart` to point `baseUrl` at your backend and update `android/app/google-services.json` with your Firebase project credentials.

---

## 10. UML Diagrams

See the [`docs/uml/`](./uml/) directory for:

* [Class Diagram](./uml/class_diagram.md) – all major classes and their relationships
* [Architecture Diagram](./uml/architecture_diagram.md) – component/layer view
* [Sequence Diagrams](./uml/sequence_diagrams.md) – key runtime flows
