# Architecture Diagram – Call Manager Mobile

> Component/layer view of the application rendered with [Mermaid](https://mermaid.js.org/).

## High-Level Component Diagram

```mermaid
graph TB
    subgraph Device["📱 Android Device"]
        subgraph Flutter["Flutter Application"]
            subgraph Presentation["Presentation Layer"]
                LS[LoginScreen]
                CS[CallScreen]
                ACS[ActiveCallScreen]
                CRS[CallRecordsScreen]
                LSc[LeadScreen]
                LDS[LeadDetailScreen]
                FUS[FollowUpScreen]
                TS[TaskScreen]
                TDS[TaskDetailScreen]
                RS[ReminderScreen]
            end

            subgraph Widgets["Shared Widgets"]
                BS[BaseScaffold]
                GD[GlobalDrawer]
                FUD[FollowUpDialog]
                RD[ReminderDialog]
                TH[ToastHelper]
                WSW[WebSocketStatusWidget]
            end

            subgraph Controllers["State Management (GetX Controllers)"]
                AC[AppController]
                LC[LeadController]
                CC[CallController]
                TC[TaskController]
            end

            subgraph Services["Business Logic Services"]
                direction TB
                AS[ApiService<br/>Dio + Interceptors]
                AuS[AuthService<br/>JWT + SecureStorage]
                NS[NetworkService<br/>Connectivity]
                LS2[LeadSyncService<br/>Periodic Sync]
                CSvc[CallSyncService<br/>Periodic Sync]
                TSvc[TaskService<br/>Pagination]
                TSS[TaskSyncService]
                FUS2[FollowUpService]
                FCMS[FCMService<br/>Firebase Messaging]
                RemS[ReminderService<br/>Local Notifications]
                WSS[WebSocketService<br/>Socket.IO]
                OSM[OfflineSyncManager]
                DSS[DataSeedingService]
            end

            subgraph Repositories["Data Access Layer (Hive)"]
                LR[LeadRepository]
                TR[TaskRepository]
                CR[CallRepository]
                FUR[FollowUpRepository]
                CDB[CallDatabaseService]
            end

            subgraph Models["Data Models"]
                LM[Lead]
                TM[Task]
                CRM[CallRecord]
                FUM[FollowUp]
                LSM[LeadStatus]
            end
        end

        subgraph Native["Android Native Layer"]
            TEL[Telephony Stack<br/>TelecomManager]
            DialerRole[Default Dialer Role<br/>InCallService]
            MethodCh[MethodChannels<br/>call_tracking_nav<br/>dialer_role]
        end

        subgraph Storage["On-Device Storage"]
            HiveDB[(Hive NoSQL<br/>Local Database)]
            SecStore[(Flutter Secure<br/>Storage - Tokens)]
            SharedPrefs[(SharedPreferences)]
        end
    end

    subgraph External["☁️ External Services"]
        Backend[Backend REST API<br/>Node.js + MongoDB]
        WSServer[WebSocket Server]
        FirebaseFCM[Firebase Cloud<br/>Messaging]
    end

    %% Presentation ↔ Controllers
    Presentation -->|observes Rx / calls methods| Controllers
    Controllers -->|updates state| Presentation

    %% Controllers ↔ Services
    LC --> LS2
    LC --> LR
    LC --> RemS
    CC --> CDB
    CC --> LC
    CC --> TC
    TC --> TSvc
    TC --> TR
    AC --> AuS

    %% Services ↔ Services
    AS --> AuS
    LS2 --> AS
    CSvc --> AS
    TSvc --> AS
    TSS --> AS
    FUS2 --> AS
    NS --> OSM
    OSM --> LS2
    OSM --> CSvc
    OSM --> TSS

    %% Repositories ↔ Storage
    LR --> HiveDB
    TR --> HiveDB
    CR --> HiveDB
    FUR --> HiveDB
    CDB --> HiveDB
    AuS --> SecStore
    AuS --> SharedPrefs

    %% Native ↔ Flutter
    TEL --> DialerRole
    DialerRole --> MethodCh
    MethodCh -->|call state events| CC
    MethodCh -->|navigation events| AC

    %% Flutter ↔ External
    AS -->|REST/HTTPS| Backend
    WSS -->|Socket.IO| WSServer
    FCMS -->|FCM push| FirebaseFCM
    FirebaseFCM -->|push to device| FCMS

    %% Styling
    classDef presentation fill:#4A90D9,stroke:#2C5F8A,color:#fff
    classDef controller fill:#7B68EE,stroke:#5A4DB8,color:#fff
    classDef service fill:#52B788,stroke:#2D6A4F,color:#fff
    classDef repository fill:#E07A5F,stroke:#B05845,color:#fff
    classDef model fill:#F4A261,stroke:#E07A5F,color:#000
    classDef storage fill:#CDB4DB,stroke:#A28BC4,color:#000
    classDef native fill:#457B9D,stroke:#1D3557,color:#fff
    classDef external fill:#264653,stroke:#1A2E38,color:#fff

    class LS,CS,ACS,CRS,LSc,LDS,FUS,TS,TDS,RS,BS,GD,FUD,RD,TH,WSW presentation
    class AC,LC,CC,TC controller
    class AS,AuS,NS,LS2,CSvc,TSvc,TSS,FUS2,FCMS,RemS,WSS,OSM,DSS service
    class LR,TR,CR,FUR,CDB repository
    class LM,TM,CRM,FUM,LSM model
    class HiveDB,SecStore,SharedPrefs storage
    class TEL,DialerRole,MethodCh native
    class Backend,WSServer,FirebaseFCM external
```

---

## Dependency Injection Map

```mermaid
graph LR
    subgraph Startup["main() – Eager Registration"]
        NW[NetworkService]
        API[ApiService]
        AUTH[AuthService]
        WS[WebSocketService]
        TS2[TaskService]
        TSS2[TaskSyncService]
        CSS2[CallSyncService]
        LSS2[LeadSyncService]
        FUS3[FollowUpService]
        CC2[CallController]
        LC2[LeadController]
        TC2[TaskController]
        AppC[AppController]
    end

    subgraph RouteBindings["Route Bindings – Lazy Registration"]
        subgraph AppBinding["AppBinding"]
            AB_AC[AppController]
        end
        subgraph LeadBinding["LeadBinding"]
            LB_LC[LeadController]
        end
        subgraph CallBinding["CallBinding"]
            CB_CC[CallController]
        end
        subgraph TaskBinding["TaskBinding"]
            TB_TC[TaskController]
        end
    end

    subgraph Routes["Route Activation"]
        R_Login[/login]
        R_Leads[/leads]
        R_Lead[/leadDetail]
        R_Call[/call]
        R_Tasks[/tasks]
        R_Task[/taskDetail]
        R_FollowUp[/followUps]
    end

    R_Login -.->|uses| AppBinding
    R_Leads -.->|uses| LeadBinding
    R_Lead -.->|uses| LeadBinding
    R_Call -.->|uses| CallBinding
    R_Tasks -.->|uses| TaskBinding
    R_Task -.->|uses| CallBinding
    R_FollowUp -.->|uses| LeadBinding
```

---

## Offline-First Data Flow

```mermaid
flowchart LR
    UI([UI Action])
    Controller([Controller])
    Repo[(Hive Local DB)]
    SyncSvc([Sync Service])
    NetSvc([NetworkService])
    API([Backend API])

    UI -->|user creates/updates data| Controller
    Controller -->|write, isSynced=false| Repo
    Controller -->|update reactive state| UI

    NetSvc -->|connectivity change| SyncSvc
    SyncSvc -->|read unsynchronised records| Repo
    SyncSvc -->|online?| NetSvc

    NetSvc -- "online" --> SyncSvc
    SyncSvc -->|HTTP POST/PUT| API
    API -->|200 OK| SyncSvc
    SyncSvc -->|markSynced, isSynced=true| Repo

    style Repo fill:#E07A5F,color:#fff
    style API fill:#264653,color:#fff
```
