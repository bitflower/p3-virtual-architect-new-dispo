# SignalR Foundation Setup - Effort Estimate

**Date:** 2026-01-28
**Project:** New Dispo (Angular 19 + .NET 8)
**Purpose:** Prepare foundation for real-time push communication from backend to frontend

---

## Overview

SignalR is the Microsoft-recommended solution for real-time communication between Angular and .NET applications. This document outlines the effort required to set up the foundation.

---

## Backend (.NET 8)

### Files to Create/Modify: 3-4 files

| File | Action | Effort |
|------|--------|--------|
| `Infrastructure/Hubs/NotificationHub.cs` | **Create** - Your SignalR Hub | 10-15 min |
| `Startup.cs:26` | **Modify** - Add `services.AddSignalR()` | 2 min |
| `Startup.cs:129` | **Modify** - Map hub endpoint | 2 min |
| `Infrastructure/ServiceSetupExtensions/SignalRSetup.cs` | **Create** (optional) - Follow your pattern | 5 min |

**Total Backend: 20-25 minutes**

### Code Changes

#### 1. Add SignalR to Services (Startup.cs:26)

```csharp
// In ConfigureServices method
services.AddSignalR(); // That's it - no package needed, built into .NET 8!
```

#### 2. Map Hub Endpoint (Startup.cs:129)

```csharp
// In Configure method
app.UseEndpoints(endpoints =>
{
    endpoints.MapControllers();
    endpoints.MapHub<NotificationHub>("/hubs/notifications"); // Add this line
});
```

#### 3. Create SignalR Hub (New File)

**Location:** `CALConsult.Disposition.API/Infrastructure/Hubs/NotificationHub.cs`

```csharp
using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace CALConsult.Disposition.API.Infrastructure.Hubs;

public class NotificationHub : Hub
{
    public async Task SendMessage(string message)
    {
        await Clients.All.SendAsync("ReceiveMessage", message);
    }

    public async Task SendToUser(string userId, string message)
    {
        await Clients.User(userId).SendAsync("ReceiveMessage", message);
    }

    public async Task SendToGroup(string groupName, string message)
    {
        await Clients.Group(groupName).SendAsync("ReceiveMessage", message);
    }
}
```

#### 4. Optional: Create Setup Extension (Following Your Pattern)

**Location:** `CALConsult.Disposition.API/Infrastructure/ServiceSetupExtensions/SignalRSetup.cs`

```csharp
using Microsoft.Extensions.DependencyInjection;

namespace CALConsult.Disposition.API.Infrastructure.ServiceSetupExtensions;

public static class SignalRSetup
{
    public static IServiceCollection AddOwnSignalR(this IServiceCollection services)
    {
        services.AddSignalR(options =>
        {
            options.EnableDetailedErrors = true; // Only for dev/staging
            options.KeepAliveInterval = TimeSpan.FromSeconds(15);
            options.ClientTimeoutInterval = TimeSpan.FromSeconds(30);
        });

        return services;
    }
}
```

Then use it in Startup.cs:
```csharp
services.AddOwnSignalR();
```

---

## Frontend (Angular 19)

### Files to Create/Modify: 2-3 files

| File | Action | Effort |
|------|--------|--------|
| `package.json` | **Modify** - Add `@microsoft/signalr` | 1 min |
| `app/services/signalr.service.ts` | **Create** - SignalR service | 15-20 min |
| `app/app.config.ts` | **Modify** - Provide service (if needed) | 2 min |

**Total Frontend: 20-25 minutes**

### Code Changes

#### 1. Install Package

```bash
npm install @microsoft/signalr@^10.0.0
```

Add to `package.json` dependencies:
```json
"@microsoft/signalr": "^10.0.0"
```

#### 2. Create SignalR Service

**Location:** `apps/nagel-cal-disposition/src/app/services/signalr.service.ts`

```typescript
import { Injectable } from '@angular/core';
import * as signalR from '@microsoft/signalr';
import { Observable, Subject } from 'rxjs';

export interface SignalRMessage {
  type: string;
  payload: any;
}

@Injectable({ providedIn: 'root' })
export class SignalRService {
  private hubConnection?: signalR.HubConnection;
  private messageReceived = new Subject<SignalRMessage>();
  private connectionState = new Subject<signalR.HubConnectionState>();

  constructor() {}

  /**
   * Start connection to SignalR hub
   * @param hubUrl - Full URL to the hub endpoint (e.g., 'http://localhost:5000/hubs/notifications')
   * @param accessToken - Optional JWT token for authentication
   */
  async startConnection(hubUrl: string, accessToken?: string): Promise<void> {
    const builder = new signalR.HubConnectionBuilder()
      .withUrl(hubUrl, {
        accessTokenFactory: () => accessToken || '',
        skipNegotiation: false,
        transport: signalR.HttpTransportType.WebSockets | signalR.HttpTransportType.ServerSentEvents
      })
      .withAutomaticReconnect({
        nextRetryDelayInMilliseconds: retryContext => {
          // Exponential backoff: 0s, 2s, 10s, 30s, then 30s
          if (retryContext.previousRetryCount === 0) return 0;
          if (retryContext.previousRetryCount === 1) return 2000;
          if (retryContext.previousRetryCount === 2) return 10000;
          return 30000;
        }
      })
      .configureLogging(signalR.LogLevel.Information);

    this.hubConnection = builder.build();

    // Setup reconnection handlers
    this.hubConnection.onreconnecting(() => {
      console.log('SignalR reconnecting...');
      this.connectionState.next(signalR.HubConnectionState.Reconnecting);
    });

    this.hubConnection.onreconnected(() => {
      console.log('SignalR reconnected');
      this.connectionState.next(signalR.HubConnectionState.Connected);
    });

    this.hubConnection.onclose(() => {
      console.log('SignalR connection closed');
      this.connectionState.next(signalR.HubConnectionState.Disconnected);
    });

    try {
      await this.hubConnection.start();
      console.log('SignalR connected');
      this.connectionState.next(signalR.HubConnectionState.Connected);
    } catch (err) {
      console.error('SignalR connection error:', err);
      throw err;
    }
  }

  /**
   * Stop the connection
   */
  async stopConnection(): Promise<void> {
    if (this.hubConnection) {
      await this.hubConnection.stop();
    }
  }

  /**
   * Listen for messages from the hub
   * @param eventName - Name of the event to listen for (e.g., 'ReceiveMessage')
   */
  onMessage(eventName: string): Observable<any> {
    const subject = new Subject<any>();

    this.hubConnection?.on(eventName, (data) => {
      subject.next(data);
    });

    return subject.asObservable();
  }

  /**
   * Send message to hub
   * @param methodName - Hub method name
   * @param args - Arguments to pass to the method
   */
  async sendMessage(methodName: string, ...args: any[]): Promise<void> {
    if (this.hubConnection?.state === signalR.HubConnectionState.Connected) {
      await this.hubConnection.invoke(methodName, ...args);
    } else {
      console.warn('SignalR not connected. Message not sent.');
    }
  }

  /**
   * Get connection state observable
   */
  getConnectionState(): Observable<signalR.HubConnectionState> {
    return this.connectionState.asObservable();
  }

  /**
   * Check if connected
   */
  isConnected(): boolean {
    return this.hubConnection?.state === signalR.HubConnectionState.Connected;
  }
}
```

#### 3. Usage Example in Component

```typescript
import { Component, OnInit, OnDestroy } from '@angular/core';
import { SignalRService } from './services/signalr.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-dashboard',
  template: `
    <div>
      <p>Connection: {{ connectionStatus }}</p>
      <p>Last message: {{ lastMessage }}</p>
    </div>
  `
})
export class DashboardComponent implements OnInit, OnDestroy {
  connectionStatus = 'Disconnected';
  lastMessage = '';
  private messageSubscription?: Subscription;

  constructor(private signalRService: SignalRService) {}

  async ngOnInit() {
    // Start connection
    const hubUrl = 'http://localhost:5000/hubs/notifications';
    const token = 'your-jwt-token'; // Get from auth service

    try {
      await this.signalRService.startConnection(hubUrl, token);
      this.connectionStatus = 'Connected';

      // Listen for messages
      this.messageSubscription = this.signalRService
        .onMessage('ReceiveMessage')
        .subscribe((message: string) => {
          console.log('Received:', message);
          this.lastMessage = message;
        });
    } catch (err) {
      console.error('Failed to connect:', err);
      this.connectionStatus = 'Failed';
    }
  }

  ngOnDestroy() {
    this.messageSubscription?.unsubscribe();
    this.signalRService.stopConnection();
  }
}
```

---

## CORS Configuration

You already have `AddOwnCors` in Startup.cs:60. Verify it allows SignalR:

### Requirements:
- Must allow `GET`, `POST` requests
- Must allow `WebSocket` upgrade
- Must allow SignalR-specific headers

### Example CORS Configuration:

```csharp
services.AddCors(options =>
{
    options.AddPolicy("AllowSpecificOrigins", builder =>
    {
        builder
            .WithOrigins("http://localhost:4200", "https://your-frontend-domain.com")
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials(); // Required for SignalR
    });
});
```

**Effort: 5 min to verify**

---

## Total Effort Estimate

| Phase | Time |
|-------|------|
| Backend setup | 20-25 min |
| Frontend setup | 20-25 min |
| CORS verification | 5 min |
| Testing basic connection | 10 min |
| **TOTAL** | **~1 hour** |

---

## What You Get After 1 Hour

- ✅ SignalR Hub running on backend
- ✅ Angular service ready to connect
- ✅ Automatic reconnection configured
- ✅ Foundation for all real-time features
- ✅ TypeScript type safety
- ✅ Authentication support (JWT)
- ✅ Error handling and logging

---

## Fits Well with Your Existing Architecture

1. **Follows your patterns** - You already use extension methods (`AddOwnMediatr`, `AddOwnCors`) - SignalR fits perfectly
2. **Works with MediatR** - You can trigger hub notifications from MediatR handlers
3. **Keycloak compatible** - SignalR supports JWT authentication (you're already using it at line Startup.cs:50)
4. **Middleware-friendly** - Hub executes after your authentication middleware
5. **No new packages needed** - SignalR is built into .NET 8

---

## Next Steps After Foundation

Once the foundation is set up, you can build features like:

1. **Live Order Updates** - Push order status changes to users in real-time
2. **Real-time Notifications** - Alert users about important events
3. **User Presence** - Show who's online/offline
4. **Live Dashboard** - Update metrics without polling
5. **Collaborative Features** - Multiple users editing simultaneously
6. **Progress Updates** - Show long-running operation progress

Each feature would be incremental additions to the hub methods.

---

## Testing Checklist

- [ ] Backend: Hub registered in DI container
- [ ] Backend: Hub endpoint mapped correctly
- [ ] Backend: CORS allows SignalR connections
- [ ] Frontend: Package installed successfully
- [ ] Frontend: Service connects to hub
- [ ] Frontend: Can receive messages
- [ ] Frontend: Reconnection works after network drop
- [ ] Authentication: JWT token passed correctly
- [ ] Logging: Connection events visible in console

---

## Resources

### Official Documentation
- [ASP.NET Core SignalR Overview](https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction)
- [@microsoft/signalr npm package](https://www.npmjs.com/package/@microsoft/signalr)
- [Using SignalR with Angular](https://blog.logrocket.com/using-real-time-data-angular-signalr/)

### GitHub Repositories
- [dotnet/aspnetcore](https://github.com/dotnet/aspnetcore) - 37.6k stars
- Main repository containing SignalR implementation

### Statistics
- **Weekly npm downloads**: ~933,000
- **Latest version**: 10.0.0
- **Community**: Extensive Microsoft support and documentation
