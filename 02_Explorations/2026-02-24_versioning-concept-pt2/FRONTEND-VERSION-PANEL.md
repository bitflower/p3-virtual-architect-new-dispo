# Angular Frontend Version System - Code Examples

This document shows how to add runtime version loading and the version panel to your Angular frontend.

---

## Architecture Overview

```
Container Starts
    ↓
docker-entrypoint.sh generates /assets/config.json
    ↓
Angular App Starts
    ↓
APP_INITIALIZER loads /assets/config.json via HTTP
    ↓
ConfigService provides version data to app
    ↓
SystemVersionPanelComponent displays versions
```

---

## Part 1: ConfigService

### Step 1: Create Types and Service

**Create new file**: `apps/nagel-cal-disposition/src/app/config/config.types.ts`

```typescript
export interface AppConfig {
  systemVersion: string;
  componentVersion: string;
  gitCommit: string;
  showVersionPanel: string;
  components: Record<string, string>;
  services: Record<string, string>;
}

export interface LiveVersionInfo {
  component: string;
  version: string;
  systemVersion: string;
  gitCommit: string;
  status: 'ok' | 'unreachable';
}
```

**Create new file**: `apps/nagel-cal-disposition/src/app/config/config.service.ts`

```typescript
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, forkJoin, of } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { firstValueFrom } from 'rxjs';
import { AppConfig, LiveVersionInfo } from './config.types';

@Injectable({ providedIn: 'root' })
export class ConfigService {
  private config!: AppConfig;
  private http = inject(HttpClient);

  /**
   * Load configuration from /assets/config.json
   * Called by APP_INITIALIZER before app starts
   */
  async load(): Promise<void> {
    try {
      this.config = await firstValueFrom(
        this.http.get<AppConfig>('/assets/config.json')
      );
      console.log('Config loaded:', this.config);
    } catch (error) {
      console.error('Failed to load config, using defaults', error);
      this.config = {
        systemVersion: 'unknown',
        componentVersion: 'unknown',
        gitCommit: 'unknown',
        showVersionPanel: 'false',
        components: {},
        services: {}
      };
    }
  }

  /**
   * Get the loaded configuration
   */
  get version(): AppConfig {
    return this.config;
  }

  /**
   * Should the version panel be shown?
   */
  get showPanel(): boolean {
    return this.config.showVersionPanel === 'true';
  }

  /**
   * Fetch live version information from all backend services
   */
  fetchLiveVersions(): Observable<LiveVersionInfo[]> {
    const requests = Object.entries(this.config.services).map(
      ([name, url]) =>
        this.http
          .get<LiveVersionInfo>(`${url}/version`)
          .pipe(
            map((info) => ({ ...info, status: 'ok' as const })),
            catchError((error) => {
              console.warn(`Failed to fetch version from ${name}:`, error);
              return of({
                component: name,
                version: '?',
                systemVersion: '?',
                gitCommit: '?',
                status: 'unreachable' as const,
              });
            })
          )
    );

    return requests.length > 0 ? forkJoin(requests) : of([]);
  }
}
```

---

## Part 2: APP_INITIALIZER Configuration

**Modify file**: `apps/nagel-cal-disposition/src/app/app.config.ts`

```typescript
import { ApplicationConfig, APP_INITIALIZER } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { ConfigService } from './config/config.service';
// ... your other imports

/**
 * Factory function to initialize config before app starts
 */
export function initializeApp(configService: ConfigService) {
  return () => configService.load();
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideHttpClient(),
    // ... your other providers

    // ADD THIS: Load config before app starts
    {
      provide: APP_INITIALIZER,
      useFactory: initializeApp,
      deps: [ConfigService],
      multi: true,
    },
  ],
};
```

---

## Part 3: Version Panel Component

**Create new file**: `apps/nagel-cal-disposition/src/app/components/system-version-panel/system-version-panel.component.ts`

```typescript
import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ConfigService, LiveVersionInfo } from '../../config/config.service';

@Component({
  selector: 'app-system-version-panel',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="panel" [class.open]="isOpen()">
      <!-- Toggle Button -->
      <button class="toggle" (click)="togglePanel()">
        System v{{ config.version.systemVersion }}
        <span class="arrow">{{ isOpen() ? '▼' : '▲' }}</span>
      </button>

      @if (isOpen()) {
        <div class="content">
          <!-- Manifest (Expected State) -->
          <h4>Manifest (Expected)</h4>
          <table>
            <thead>
              <tr>
                <th>Component</th>
                <th>Version</th>
              </tr>
            </thead>
            <tbody>
              @for (entry of manifestEntries; track entry[0]) {
                <tr>
                  <td>{{ entry[0] }}</td>
                  <td class="mono">{{ entry[1] }}</td>
                </tr>
              }
            </tbody>
          </table>

          <!-- Live (Actual State) -->
          <h4>
            Live (Actual)
            <button class="refresh" (click)="loadLiveVersions()" title="Refresh">
              ↻
            </button>
          </h4>

          @if (liveVersions()) {
            <table>
              <thead>
                <tr>
                  <th>Component</th>
                  <th>Version</th>
                  <th>Commit</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                @for (svc of liveVersions(); track svc.component) {
                  <tr [class.mismatch]="isMismatch(svc)">
                    <td>{{ svc.component }}</td>
                    <td class="mono">{{ svc.version }}</td>
                    <td class="mono">{{ svc.gitCommit.slice(0, 7) }}</td>
                    <td>
                      @if (svc.status === 'ok') {
                        <span class="status-ok">✅</span>
                      } @else {
                        <span class="status-error">❌</span>
                      }
                    </td>
                  </tr>
                }
              </tbody>
            </table>
          } @else {
            <p class="hint">Click ↻ to fetch live versions</p>
          }

          <!-- Git Info -->
          <div class="git-info">
            <small>Frontend: v{{ config.version.componentVersion }} ({{ config.version.gitCommit.slice(0, 7) }})</small>
          </div>
        </div>
      }
    </div>
  `,
  styles: [`
    .panel {
      position: fixed;
      bottom: 0;
      right: 16px;
      background: #1a1a2e;
      color: #e0e0e0;
      border-radius: 8px 8px 0 0;
      font-size: 12px;
      z-index: 9999;
      min-width: 380px;
      max-width: 500px;
      box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.4);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }

    .toggle {
      width: 100%;
      padding: 10px 14px;
      background: #16213e;
      color: #00d9ff;
      border: none;
      cursor: pointer;
      font-family: 'Courier New', monospace;
      font-size: 13px;
      font-weight: 600;
      border-radius: 8px 8px 0 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
      transition: background 0.2s;
    }

    .toggle:hover {
      background: #1e2d4d;
    }

    .arrow {
      font-size: 10px;
      color: #00d9ff;
    }

    .content {
      padding: 12px;
      max-height: 500px;
      overflow-y: auto;
    }

    h4 {
      color: #00d9ff;
      margin: 16px 0 8px;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      display: flex;
      align-items: center;
      gap: 8px;
      font-weight: 600;
    }

    h4:first-child {
      margin-top: 4px;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 12px;
    }

    th {
      text-align: left;
      color: #888;
      font-weight: 600;
      padding: 6px 8px;
      font-size: 10px;
      text-transform: uppercase;
      border-bottom: 1px solid #2a2a3e;
      letter-spacing: 0.5px;
    }

    td {
      padding: 6px 8px;
      border-bottom: 1px solid #252535;
    }

    tbody tr:last-child td {
      border-bottom: none;
    }

    tbody tr:hover {
      background: rgba(0, 217, 255, 0.05);
    }

    .mono {
      font-family: 'SF Mono', 'Fira Code', 'Courier New', monospace;
      font-size: 11px;
    }

    .mismatch {
      background: rgba(255, 80, 80, 0.12);
    }

    .mismatch td {
      color: #ff9999;
    }

    .status-ok {
      font-size: 14px;
    }

    .status-error {
      font-size: 14px;
      filter: grayscale(50%);
    }

    .refresh {
      background: none;
      border: none;
      color: #00d9ff;
      cursor: pointer;
      font-size: 18px;
      padding: 0 6px;
      line-height: 1;
      transition: transform 0.2s;
    }

    .refresh:hover {
      color: #00ffff;
      transform: rotate(180deg);
    }

    .hint {
      color: #666;
      font-style: italic;
      margin: 8px 0;
      font-size: 11px;
    }

    .git-info {
      margin-top: 12px;
      padding-top: 8px;
      border-top: 1px solid #2a2a3e;
      color: #666;
      font-size: 10px;
    }

    /* Scrollbar styling */
    .content::-webkit-scrollbar {
      width: 6px;
    }

    .content::-webkit-scrollbar-track {
      background: #1a1a2e;
    }

    .content::-webkit-scrollbar-thumb {
      background: #444;
      border-radius: 3px;
    }

    .content::-webkit-scrollbar-thumb:hover {
      background: #555;
    }
  `],
})
export class SystemVersionPanelComponent {
  config = inject(ConfigService);
  isOpen = signal(false);
  liveVersions = signal<LiveVersionInfo[] | null>(null);

  get manifestEntries(): [string, string][] {
    return Object.entries(this.config.version.components);
  }

  togglePanel(): void {
    this.isOpen.update(v => !v);
  }

  loadLiveVersions(): void {
    this.config.fetchLiveVersions().subscribe((versions) => {
      this.liveVersions.set(versions);
    });
  }

  isMismatch(svc: LiveVersionInfo): boolean {
    const expected = this.config.version.components[svc.component];
    return expected != null && expected !== svc.version && svc.status === 'ok';
  }
}
```

---

## Part 4: Add to App Component

**Modify file**: `apps/nagel-cal-disposition/src/app/app.component.ts`

```typescript
import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { SystemVersionPanelComponent } from './components/system-version-panel/system-version-panel.component';
import { ConfigService } from './config/config.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterOutlet,
    SystemVersionPanelComponent,  // ADD THIS
    // ... your other imports
  ],
  template: `
    <router-outlet />

    <!-- ADD THIS: Show version panel if enabled -->
    @if (config.showPanel) {
      <app-system-version-panel />
    }
  `,
  // ... your styles
})
export class AppComponent {
  config = inject(ConfigService);  // ADD THIS
  // ... your existing code
}
```

---

## Part 5: Assets Config Template

**Create new file**: `apps/nagel-cal-disposition/src/assets/config.json`

This is a **fallback** for local development. In production, it's overwritten by docker-entrypoint.sh.

```json
{
  "systemVersion": "dev",
  "componentVersion": "dev",
  "gitCommit": "local",
  "showVersionPanel": "true",
  "components": {
    "disposition-backend": "dev",
    "tms-bridge": "dev",
    "disposition-frontend": "dev"
  },
  "services": {
    "disposition-backend": "http://localhost:5101/api",
    "tms-bridge": "http://localhost:7153/api"
  }
}
```

---

## Part 6: Docker Configuration (Already Covered)

Reminder from previous document:

1. **Dockerfile** - Add entrypoint
2. **docker-entrypoint.sh** - Generate config.json at runtime

These files inject environment variables into `/assets/config.json` when the container starts.

---

## Part 7: Local Development Testing

### Option 1: Use Default config.json

Just run the app normally:

```bash
npm run cal:start
```

The app will load `/assets/config.json` and show "dev" versions.

### Option 2: Simulate Production

Create a script to generate config.json:

**Create**: `scripts/generate-config.sh`

```bash
#!/bin/bash

cat > apps/nagel-cal-disposition/src/assets/config.json <<EOF
{
  "systemVersion": "${SYSTEM_VERSION:-1}",
  "componentVersion": "${COMPONENT_VERSION:-0.1.0}",
  "gitCommit": "${GIT_COMMIT:-abc123}",
  "showVersionPanel": "true",
  "components": {
    "disposition-backend": "1.2.3",
    "tms-bridge": "2.1.0",
    "disposition-frontend": "1.5.0"
  },
  "services": {
    "disposition-backend": "http://localhost:5101/api",
    "tms-bridge": "http://localhost:7153/api"
  }
}
EOF
```

Run before starting:

```bash
SYSTEM_VERSION=42 COMPONENT_VERSION=1.5.0 GIT_COMMIT=abc123 bash scripts/generate-config.sh
npm run cal:start
```

---

## Part 8: Production Behavior

### Container Startup

```
1. Container starts
2. docker-entrypoint.sh runs
3. Generates /usr/share/nginx/html/assets/config.json from env vars:
   - SYSTEM_VERSION=42
   - COMPONENT_VERSION=1.5.0
   - GIT_COMMIT=abc123
   - SHOW_VERSION_PANEL=true
   - COMPONENT_MANIFEST={"disposition-backend":"1.2.3",...}
4. Nginx starts and serves the app
5. Angular loads /assets/config.json via HTTP
6. Version panel shows in bottom-right corner
```

### User Experience

**Test Environment** (SHOW_VERSION_PANEL=true):
- Version panel visible in bottom-right
- Click to expand and see versions
- Click refresh to query live backend versions
- Mismatches highlighted in red

**Production Environment** (SHOW_VERSION_PANEL=false):
- Version panel hidden
- Config still loaded (available in code if needed)
- Can still access via DevTools: `window.ng.getComponent($0).config.version`

---

## Part 9: Advanced Features

### Add to Navbar

```typescript
// In your navbar component
export class NavbarComponent {
  config = inject(ConfigService);

  get systemVersion(): string {
    return this.config.version.systemVersion;
  }
}
```

```html
<!-- In navbar template -->
<div class="version-badge">
  System v{{ systemVersion }}
</div>
```

### Error Reporting Integration

Include version in error reports:

```typescript
// In error handler
export class GlobalErrorHandler implements ErrorHandler {
  config = inject(ConfigService);

  handleError(error: Error): void {
    const errorReport = {
      message: error.message,
      stack: error.stack,
      systemVersion: this.config.version.systemVersion,
      componentVersion: this.config.version.componentVersion,
      gitCommit: this.config.version.gitCommit,
      timestamp: new Date().toISOString()
    };

    // Send to logging service
    console.error('Error Report:', errorReport);
  }
}
```

### Analytics Integration

```typescript
// When user logs in or app starts
analytics.setUserProperties({
  system_version: this.config.version.systemVersion,
  frontend_version: this.config.version.componentVersion
});
```

---

## Testing Checklist

### Local Development
- [ ] App starts without errors
- [ ] config.json loads successfully
- [ ] Version panel shows "dev" versions
- [ ] Console shows "Config loaded"

### Docker Build
- [ ] Docker build succeeds
- [ ] Container starts
- [ ] config.json generated correctly
- [ ] Nginx serves app

### Deployed Environment
- [ ] Version panel visible (if SHOW_VERSION_PANEL=true)
- [ ] Shows correct system version
- [ ] Shows correct component versions
- [ ] Live version refresh works
- [ ] Backend API calls succeed
- [ ] CORS configured correctly

---

## Troubleshooting

### Panel doesn't show
- Check `SHOW_VERSION_PANEL=true` in deployment
- Check `config.showPanel` in DevTools
- Verify config.json loaded correctly

### "Unknown" versions shown
- Check environment variables in Cloud Run deployment
- Verify docker-entrypoint.sh executed
- Check container logs for errors

### Live versions show "unreachable"
- Check backend `/api/version` endpoints exist
- Verify CORS configuration
- Check network connectivity
- Inspect browser console for errors

### Config.json not loading
- Check file exists at `/assets/config.json`
- Verify nginx serves static files correctly
- Check browser network tab for 404 errors

---

## Summary

### Files to Create:
1. `config/config.types.ts` - Type definitions
2. `config/config.service.ts` - Config service with HTTP loading
3. `components/system-version-panel/system-version-panel.component.ts` - UI component
4. `assets/config.json` - Default config for local dev

### Files to Modify:
1. `app.config.ts` - Add APP_INITIALIZER
2. `app.component.ts` - Add version panel to template

### Environment Variables Used:
- `SYSTEM_VERSION` - System version number
- `COMPONENT_VERSION` - Frontend version
- `GIT_COMMIT` - Git commit hash
- `SHOW_VERSION_PANEL` - Show/hide panel (true/false)
- `COMPONENT_MANIFEST` - JSON of all component versions

All of this works **without rebuilding** the Docker image - just restart with new env vars!
