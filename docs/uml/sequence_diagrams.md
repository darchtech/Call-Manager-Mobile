# UML Sequence Diagrams – Call Manager Mobile

> Key runtime interactions rendered with [Mermaid](https://mermaid.js.org/).

---

## 1. User Login Flow

```mermaid
sequenceDiagram
    actor User
    participant LoginScreen
    participant AuthService
    participant ApiService
    participant SecureStorage
    participant FCMService
    participant AppController

    User->>LoginScreen: Enter email & password → tap Login
    LoginScreen->>AuthService: login(email, password)
    AuthService->>ApiService: post('/auth/login', {email, password})
    ApiService-->>AuthService: {accessToken, refreshToken, user}
    AuthService->>SecureStorage: saveTokens(access, refresh)
    AuthService->>FCMService: getToken()
    FCMService-->>AuthService: fcmToken
    AuthService->>ApiService: post('/auth/fcm-token', {fcmToken})
    ApiService-->>AuthService: 200 OK
    AuthService-->>LoginScreen: true (login success)
    LoginScreen->>AppController: getInitialRoute()
    AppController-->>LoginScreen: '/leads'
    LoginScreen->>LoginScreen: Get.offAllNamed('/leads')
```

---

## 2. Outbound Call Tracking Flow

```mermaid
sequenceDiagram
    actor Agent
    participant LeadScreen
    participant CallController
    participant UrlLauncher
    participant AndroidTelephony
    participant CallDatabaseService
    participant LeadController
    participant TaskController
    participant CallSyncService

    Agent->>LeadScreen: Tap call button on lead
    LeadScreen->>CallController: startCallForLead(lead)
    CallController->>CallController: create CallRecord (status=CALL_DIALING)
    CallController->>CallDatabaseService: saveCallRecord(record)
    CallController->>UrlLauncher: launch(tel:<number>)
    UrlLauncher->>AndroidTelephony: open dialler / initiate call

    Note over AndroidTelephony: Call state machine runs in background

    AndroidTelephony->>CallController: MethodChannel → CALL_CONNECTING
    CallController->>CallController: updateStatus(CALL_CONNECTING)

    AndroidTelephony->>CallController: MethodChannel → CALL_CONNECTED
    CallController->>CallController: record.connectedAt = now

    AndroidTelephony->>CallController: MethodChannel → CALL_ENDED_BY_CALLER
    CallController->>CallController: record.endedAt = now, calculateDuration()
    CallController->>CallDatabaseService: saveCallRecord(record)
    CallController->>LeadController: updateCallStatus(leadId, 'CALL_ENDED_BY_CALLER')
    LeadController->>LeadController: lead.updateCallStatus('CALL_ENDED_BY_CALLER')
    LeadController->>LeadController: isSynced = false
    LeadController->>TaskController: recalculateTaskCompletionForLead(leadId)
    TaskController->>TaskController: update completedCount/totalCount
    CallController->>CallSyncService: queueRecord(record)
    CallSyncService-->>CallController: queued
```

---

## 3. Lead Sync (Offline → Online)

```mermaid
sequenceDiagram
    participant Timer
    participant LeadSyncService
    participant NetworkService
    participant LeadRepository
    participant ApiService
    participant Backend

    Timer->>LeadSyncService: periodic tick (every 5 min)
    LeadSyncService->>NetworkService: isConnected?
    alt Offline
        NetworkService-->>LeadSyncService: false
        LeadSyncService->>LeadSyncService: skip sync, return
    else Online
        NetworkService-->>LeadSyncService: true
        LeadSyncService->>LeadRepository: getUnsyncedLeads()
        LeadRepository-->>LeadSyncService: [lead1, lead2, ...]
        loop For each unsynced lead
            LeadSyncService->>ApiService: createLead(lead) or updateLead(lead)
            ApiService->>Backend: POST/PUT /leads
            Backend-->>ApiService: 200 OK {updatedLead}
            ApiService-->>LeadSyncService: success
            LeadSyncService->>LeadRepository: lead.markSynced()
        end
    end
```

---

## 4. JWT Token Refresh Flow

```mermaid
sequenceDiagram
    participant Service
    participant ApiService
    participant AuthService
    participant Backend
    participant SecureStorage

    Service->>ApiService: get('/some-endpoint')
    ApiService->>Backend: GET /some-endpoint (Bearer accessToken)
    Backend-->>ApiService: 401 Unauthorized (token expired)
    ApiService->>AuthService: refreshToken()
    AuthService->>SecureStorage: getRefreshToken()
    SecureStorage-->>AuthService: refreshToken
    AuthService->>Backend: POST /auth/refresh {refreshToken}
    alt Refresh success
        Backend-->>AuthService: {newAccessToken, newRefreshToken}
        AuthService->>SecureStorage: saveTokens(new tokens)
        AuthService-->>ApiService: true
        ApiService->>Backend: GET /some-endpoint (Bearer newAccessToken)
        Backend-->>ApiService: 200 OK {data}
        ApiService-->>Service: data
    else Refresh failed
        Backend-->>AuthService: 401 / error
        AuthService->>AuthService: logout()
        AuthService-->>ApiService: false
        ApiService->>ApiService: navigate to /login
    end
```

---

## 5. Follow-Up Creation & Reminder Scheduling

```mermaid
sequenceDiagram
    actor Agent
    participant LeadDetailScreen
    participant FollowUpDialog
    participant FollowUpService
    participant ApiService
    participant FollowUpRepository
    participant ReminderService
    participant LeadController

    Agent->>LeadDetailScreen: Tap "Add Follow-up"
    LeadDetailScreen->>FollowUpDialog: show dialog
    Agent->>FollowUpDialog: Select date/time, enter note → Confirm
    FollowUpDialog->>FollowUpService: createFollowUp(followUp)
    FollowUpService->>ApiService: post('/follow-ups', followUp)
    ApiService-->>FollowUpService: {createdFollowUp}
    FollowUpService->>FollowUpRepository: saveFollowUp(createdFollowUp)
    FollowUpService->>LeadController: setFollowUpDate(leadId, date, note)
    LeadController->>LeadController: lead.setFollowUpDate(date)
    LeadController->>ReminderService: scheduleReminder(lead)
    ReminderService->>ReminderService: flutter_local_notifications.schedule(...)
    ReminderService-->>LeadController: reminder scheduled
    LeadController-->>LeadDetailScreen: state updated
    LeadDetailScreen-->>Agent: Follow-up saved ✓
```

---

## 6. FCM Push Notification Handling

```mermaid
sequenceDiagram
    participant Backend
    participant FCMServer as Firebase FCM
    participant FCMService
    participant LocalNotifications as flutter_local_notifications
    participant AppController
    actor Agent

    Backend->>FCMServer: sendNotification(fcmToken, {title, body, data})
    FCMServer->>FCMService: push message (foreground/background)
    
    alt App in Foreground
        FCMService->>FCMService: onMessage handler fires
        FCMService->>LocalNotifications: show(title, body)
        LocalNotifications-->>Agent: notification banner
    else App in Background / Terminated
        FCMService->>FCMService: onBackgroundMessage handler fires
        FCMService->>LocalNotifications: show(title, body)
        LocalNotifications-->>Agent: system notification
        Agent->>LocalNotifications: tap notification
        LocalNotifications->>FCMService: onNotificationTapped(data)
        FCMService->>AppController: navigate to relevant screen
    end
```

---

## 7. Task Completion Recalculation

```mermaid
sequenceDiagram
    participant CallController
    participant LeadController
    participant TaskController
    participant TaskRepository
    participant TaskSyncService
    participant ApiService

    CallController->>LeadController: updateCallStatus(leadId, 'CALL_ENDED_BY_CALLER')
    LeadController->>LeadController: lead.callStatus = 'CONTACTED'
    LeadController->>TaskController: recalculateTaskCompletionForLead(leadId)

    TaskController->>TaskRepository: getAllTasks()
    TaskRepository-->>TaskController: [task1, task2, ...]

    loop For each task linked to this lead
        TaskController->>TaskController: count leads with CONTACTED status
        TaskController->>TaskController: update task.completedCount / task.totalCount
        TaskController->>TaskRepository: saveTask(task)
        TaskController->>TaskController: task.isSynced = false
    end

    TaskSyncService->>TaskRepository: getUnsyncedTasks()
    TaskRepository-->>TaskSyncService: [task1, ...]
    TaskSyncService->>ApiService: put('/tasks/{id}', task)
    ApiService-->>TaskSyncService: 200 OK
    TaskSyncService->>TaskRepository: task.markSynced()
```
