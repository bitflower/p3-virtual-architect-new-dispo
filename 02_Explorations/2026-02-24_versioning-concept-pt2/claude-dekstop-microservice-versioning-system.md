# Microservice Versionierungssystem mit System-Version

## Übersicht

Dieses Dokument beschreibt ein dezentrales Versionierungssystem für eine Microservice-Architektur. Bei jedem Release einer Komponente wird automatisch eine monoton steigende **System-Version** erzeugt. Alle Versionsinformationen leben in Git-Repos, Git-Tags und Docker-Labels – kein zentraler Versionierungsservice nötig.

```
System-Version v42
├── service-auth      v2.1.0
├── service-orders    v3.4.1
├── service-payments  v1.8.0
├── service-gateway   v5.0.2
└── frontend          v1.5.0
```

---

## Architektur

### Datenfluss bei einem Release

```
Developer pusht Tag v3.4.1 auf service-orders
        │
        ▼
   CI-Pipeline
        │
        ├──► Docker-Image: registry/service-orders:3.4.1
        │    (Labels: system.version=43, component.version=3.4.1, git.commit=a1b2c3d)
        │
        ├──► Docker-Image Re-Tag: registry/service-orders:system-v43
        │
        ├──► system-manifest Repo: commit + tag "system-v43"
        │    (versions.json = Snapshot aller Komponenten-Versionen)
        │
        ├──► service-orders Repo: zusätzlicher Tag "system-v43"
        │
        └──► Auto-Deploy auf Testumgebung
```

### Wo lebt welche Information?

| Frage                                         | Wo nachschauen                                               |
| --------------------------------------------- | ------------------------------------------------------------ |
| Welche Komponenten gehören zu System v42?     | `system-manifest` → `git show system-v42:versions.json`      |
| Welche System-Version hat service-orders v3.4.1? | `service-orders` Repo → `git tag --contains v3.4.1`      |
| Was läuft gerade im Cluster?                  | `docker inspect` Labels oder Kubernetes Annotations          |
| Code für System v42 auschecken?               | In jedem Repo: `git checkout system-v42`                     |
| Wann wurde System v42 released?               | `system-manifest` → `git log system-v42`                     |
| Soll vs. Ist einer Testumgebung?              | Frontend Version-Panel (Manifest vs. Live-Endpoints)         |

---

## 1. System-Manifest-Repo

Ein schlankes Git-Repo (`system-manifest`) enthält eine einzige Datei, die bei jedem Komponenten-Release aktualisiert wird. Es ist kein zentraler Service, sondern ein normales Git-Repo – klonbar, offline lesbar, versioniert.

### `versions.json`

```json
{
  "system_version": 42,
  "components": {
    "service-auth": "2.1.0",
    "service-orders": "3.4.1",
    "service-payments": "1.8.0",
    "service-gateway": "5.0.2",
    "frontend": "1.5.0"
  },
  "released_at": "2026-02-23T14:30:00Z",
  "trigger": {
    "component": "service-orders",
    "from_version": "3.4.0",
    "to_version": "3.4.1",
    "git_commit": "a1b2c3d"
  }
}
```

Jeder Commit = eine System-Version. Die gesamte Historie ist über `git log` nachvollziehbar:

```
$ git log --oneline -10

f4e2a1b  v52: service-auth → 2.2.0
c3d4e5f  v51: service-orders → 3.5.0
a1b2c3d  v50: service-gateway → 5.1.0
9e8d7c6  v49: service-orders → 3.4.2
7b6a5d4  v48: frontend → 1.6.0
5f4e3d2  v47: service-payments → 1.8.1
3c2b1a0  v46: service-auth → 2.1.1
1a0b9c8  v45: service-orders → 3.4.1
e9d8c7b  v44: service-auth → 2.1.0
d8c7b6a  v43: service-payments → 1.8.0
```

---

## 2. Git-Tags (doppelt getaggt)

Jedes Component-Repo bekommt zwei Tags pro Release:

```bash
# Im Component-Repo (z.B. service-orders):
git tag v3.4.1         # eigene Semver
git tag system-v43     # zugehörige System-Version
```

Entwickler können so sofort:

```bash
# Welche System-Version hatte dieses Release?
git tag --contains <commit>

# Code einer bestimmten System-Version auschecken:
git checkout system-v43
```

---

## 3. Docker-Image-Labels

### Dockerfile (jeder Service)

```dockerfile
# Labels werden beim Build via --label gesetzt (siehe CI/CD Pipeline)
```

### Build-Kommando

```bash
docker build \
  --label "org.mycompany.component.version=3.4.1" \
  --label "org.mycompany.system.version=43" \
  --label "org.mycompany.git.commit=a1b2c3d" \
  --label "org.mycompany.git.repo=service-orders" \
  -t registry/service-orders:3.4.1 .
```

### Abfrage im laufenden System

```bash
# Was läuft gerade?
docker inspect service-orders | jq '.[0].Config.Labels'

# Alle System-Versionen aller Container:
docker ps --format '{{.Names}}' | xargs -I{} \
  docker inspect {} --format '{{.Name}} → system-v{{index .Config.Labels "org.mycompany.system.version"}}'
```

---

## 4. Automatische Versionierung (CI/CD)

### Race-Condition-Problem

Bei mehreren Releases am Tag (z.B. 10+) können zwei Pipelines gleichzeitig bumpen:

```
Pipeline A (service-auth):    liest v42 → schreibt v43
Pipeline B (service-orders):  liest v42 → schreibt v43  ← Konflikt!
```

### Lösung: Atomarer Bump mit Retry-Loop

**`bump-system-version.sh`** – lebt im Manifest-Repo, wird von allen CI-Pipelines genutzt:

```bash
#!/bin/bash
set -e

COMPONENT_NAME=$1    # z.B. "service-orders"
COMPONENT_VERSION=$2 # z.B. "3.4.1"
GIT_COMMIT=$3        # z.B. "a1b2c3d"
MAX_RETRIES=10

MANIFEST_REPO="https://${GIT_TOKEN}@github.com/org/system-manifest.git"
WORK_DIR=$(mktemp -d)

git config --global user.email "ci@mycompany.com"
git config --global user.name "CI Bot"

for ATTEMPT in $(seq 1 $MAX_RETRIES); do
  echo "Attempt ${ATTEMPT}/${MAX_RETRIES}"

  # Frisch klonen – immer neuester Stand
  rm -rf "${WORK_DIR}/manifest"
  git clone --depth 1 "${MANIFEST_REPO}" "${WORK_DIR}/manifest"
  cd "${WORK_DIR}/manifest"

  # Atomar: Version lesen → inkrementieren → schreiben
  CURRENT=$(jq '.system_version' versions.json)
  NEW_VERSION=$((CURRENT + 1))

  jq \
    --arg comp "$COMPONENT_NAME" \
    --arg ver "$COMPONENT_VERSION" \
    --arg commit "$GIT_COMMIT" \
    --argjson sysver "$NEW_VERSION" \
    '
      .system_version = $sysver
      | .released_at = (now | todate)
      | .trigger = {
          component: $comp,
          from_version: .components[$comp],
          to_version: $ver,
          git_commit: $commit
        }
      | .components[$comp] = $ver
    ' versions.json > tmp.json && mv tmp.json versions.json

  git add versions.json
  git commit -m "v${NEW_VERSION}: ${COMPONENT_NAME} → ${COMPONENT_VERSION}"
  git tag "system-v${NEW_VERSION}"

  # Push – schlägt fehl wenn jemand schneller war
  if git push && git push --tags; then
    echo "✅ System-Version: ${NEW_VERSION}"
    # Output für GitHub Actions
    echo "SYSTEM_VERSION=${NEW_VERSION}" >> "$GITHUB_OUTPUT" 2>/dev/null || true
    rm -rf "${WORK_DIR}"
    exit 0
  fi

  echo "⚠️  Push fehlgeschlagen (concurrent update), retry..."
  sleep $((RANDOM % 3 + 1))
done

echo "❌ Max retries erreicht"
rm -rf "${WORK_DIR}"
exit 1
```

**Warum das funktioniert:** `git push` schlägt atomar fehl wenn der Remote weiter ist. Der nächste Versuch klont frisch, liest die Version die der Andere geschrieben hat, und inkrementiert darauf.

---

### GitHub Actions Workflow (Reusable – in jedem Service-Repo)

**`.github/workflows/release.yml`**:

```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    outputs:
      system_version: ${{ steps.bump.outputs.SYSTEM_VERSION }}
      version: ${{ steps.meta.outputs.VERSION }}
      component: ${{ steps.meta.outputs.COMPONENT }}
      commit: ${{ steps.meta.outputs.COMMIT }}

    steps:
      - uses: actions/checkout@v4

      - name: Extract version metadata
        id: meta
        run: |
          echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
          echo "COMMIT=$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT
          echo "COMPONENT=${GITHUB_REPOSITORY#*/}" >> $GITHUB_OUTPUT

      # ── Docker Image bauen & pushen ──
      - name: Build & Push Docker Image
        run: |
          VERSION=${{ steps.meta.outputs.VERSION }}
          COMPONENT=${{ steps.meta.outputs.COMPONENT }}
          COMMIT=${{ steps.meta.outputs.COMMIT }}

          docker build \
            --label "org.mycompany.component.version=${VERSION}" \
            --label "org.mycompany.git.commit=${COMMIT}" \
            --label "org.mycompany.git.repo=${COMPONENT}" \
            -t registry/${COMPONENT}:${VERSION} .

          docker push registry/${COMPONENT}:${VERSION}

      # ── System-Version bumpen (mit Retry bei Konflikten) ──
      - name: Bump System Version
        id: bump
        env:
          GIT_TOKEN: ${{ secrets.MANIFEST_REPO_TOKEN }}
        run: |
          curl -sL "https://raw.githubusercontent.com/org/system-manifest/main/bump-system-version.sh" \
            | bash -s "${{ steps.meta.outputs.COMPONENT }}" \
                      "${{ steps.meta.outputs.VERSION }}" \
                      "${{ steps.meta.outputs.COMMIT }}"

      # ── System-Tag ins eigene Repo setzen ──
      - name: Tag own repo with system version
        env:
          GIT_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          SYS_VERSION=${{ steps.bump.outputs.SYSTEM_VERSION }}
          git tag "system-v${SYS_VERSION}"
          git push origin "system-v${SYS_VERSION}"

      # ── Docker-Image mit System-Version re-taggen ──
      - name: Tag Docker image with system version
        run: |
          VERSION=${{ steps.meta.outputs.VERSION }}
          COMPONENT=${{ steps.meta.outputs.COMPONENT }}
          SYS_VERSION=${{ steps.bump.outputs.SYSTEM_VERSION }}

          docker tag registry/${COMPONENT}:${VERSION} \
                     registry/${COMPONENT}:system-v${SYS_VERSION}
          docker push registry/${COMPONENT}:system-v${SYS_VERSION}

  # ── Auto-Deploy auf Testumgebung ──
  deploy-test:
    needs: release
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to test environment
        run: |
          helm upgrade ${{ needs.release.outputs.component }} ./chart \
            --set image.tag=${{ needs.release.outputs.version }} \
            --set env.SYSTEM_VERSION=${{ needs.release.outputs.system_version }} \
            --set env.COMPONENT_VERSION=${{ needs.release.outputs.version }} \
            --set env.GIT_COMMIT=${{ needs.release.outputs.commit }} \
            --set env.COMPONENT_MANIFEST="$(curl -sL https://raw.githubusercontent.com/org/system-manifest/main/versions.json | jq -c '.components')" \
            -n test
```

### Entwickler-Workflow

Der Entwickler muss **nichts manuell tun** außer einen Tag zu pushen:

```bash
# Das ist ALLES was der Entwickler macht:
git tag v3.4.1
git push origin v3.4.1

# Alles andere passiert automatisch:
# ✅ Docker Image gebaut & gepusht
# ✅ System-Version (z.B. v43) erzeugt
# ✅ Manifest aktualisiert
# ✅ Git-Tags gesetzt (eigenes Repo + Manifest)
# ✅ Docker-Image re-getaggt
# ✅ Auf Testumgebung deployed
```

---

## 5. Version-Endpoint in jedem Microservice

Jeder Service exponiert einen `/version`-Endpoint für die Live-Abfrage durch das Frontend.

### NestJS Beispiel

```typescript
// src/version/version.controller.ts
import { Controller, Get } from '@nestjs/common';

@Controller()
export class VersionController {
  @Get('version')
  getVersion() {
    return {
      component: process.env.COMPONENT_NAME ?? 'unknown',
      version: process.env.COMPONENT_VERSION ?? 'unknown',
      systemVersion: process.env.SYSTEM_VERSION ?? 'unknown',
      gitCommit: process.env.GIT_COMMIT ?? 'unknown',
    };
  }
}
```

### Spring Boot Beispiel

```java
@RestController
public class VersionController {
    @Value("${COMPONENT_NAME:unknown}") private String componentName;
    @Value("${COMPONENT_VERSION:unknown}") private String componentVersion;
    @Value("${SYSTEM_VERSION:unknown}") private String systemVersion;
    @Value("${GIT_COMMIT:unknown}") private String gitCommit;

    @GetMapping("/version")
    public Map<String, String> getVersion() {
        return Map.of(
            "component", componentName,
            "version", componentVersion,
            "systemVersion", systemVersion,
            "gitCommit", gitCommit
        );
    }
}
```

---

## 6. Angular Frontend – Version-Anzeige ohne Redeploy

### Konzept

Eine `config.json` wird beim **Container-Start** (nicht beim Build) generiert. Angular lädt sie zur Laufzeit. Das gleiche Image kann in verschiedenen Umgebungen mit unterschiedlichen Versionen laufen.

### 6.1 Platzhalter-Datei im Repo

**`src/assets/config.json`** (Default/Fallback für lokale Entwicklung):

```json
{
  "systemVersion": "dev",
  "componentVersion": "dev",
  "gitCommit": "local",
  "showVersionPanel": "true",
  "components": {},
  "services": {
    "auth": "/api/auth",
    "orders": "/api/orders",
    "payments": "/api/payments",
    "gateway": "/api/gateway"
  }
}
```

### 6.2 Docker-Entrypoint

**`docker-entrypoint.sh`**:

```bash
#!/bin/sh
# Wird bei jedem Container-Start ausgeführt – kein Rebuild nötig

cat > /usr/share/nginx/html/assets/config.json <<EOF
{
  "systemVersion": "${SYSTEM_VERSION:-unknown}",
  "componentVersion": "${COMPONENT_VERSION:-unknown}",
  "gitCommit": "${GIT_COMMIT:-unknown}",
  "showVersionPanel": "${SHOW_VERSION_PANEL:-false}",
  "components": ${COMPONENT_MANIFEST:-"{}"},
  "services": {
    "auth":     "${AUTH_URL:-/api/auth}",
    "orders":   "${ORDERS_URL:-/api/orders}",
    "payments": "${PAYMENTS_URL:-/api/payments}",
    "gateway":  "${GATEWAY_URL:-/api/gateway}"
  }
}
EOF

exec nginx -g 'daemon off;'
```

**`Dockerfile`** (Frontend):

```dockerfile
FROM node:20 AS build
WORKDIR /app
COPY . .
RUN npm ci && npm run build -- --configuration=production

FROM nginx:alpine
COPY --from=build /app/dist/my-app/browser /usr/share/nginx/html
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
```

### 6.3 Deployment-Konfiguration

```yaml
# docker-compose.yml oder Kubernetes Deployment
services:
  frontend:
    image: registry/frontend:1.5.0
    environment:
      SYSTEM_VERSION: "42"
      COMPONENT_VERSION: "1.5.0"
      GIT_COMMIT: "a1b2c3d"
      SHOW_VERSION_PANEL: "true"                  # false für Prod
      AUTH_URL: "/api/auth"
      ORDERS_URL: "/api/orders"
      PAYMENTS_URL: "/api/payments"
      GATEWAY_URL: "/api/gateway"
      COMPONENT_MANIFEST: |
        {
          "service-auth": "2.1.0",
          "service-orders": "3.4.1",
          "service-payments": "1.8.0",
          "service-gateway": "5.0.2",
          "frontend": "1.5.0"
        }
```

Version ändern = Container neu starten, nicht neu bauen:

```bash
SYSTEM_VERSION=43 docker compose up -d frontend
```

### 6.4 Angular ConfigService

**`src/app/config.service.ts`**:

```typescript
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, forkJoin, of } from 'rxjs';
import { map, catchError } from 'rxjs/operators';
import { firstValueFrom } from 'rxjs';

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

@Injectable({ providedIn: 'root' })
export class ConfigService {
  private config!: AppConfig;
  private http = inject(HttpClient);

  async load(): Promise<void> {
    this.config = await firstValueFrom(
      this.http.get<AppConfig>('/assets/config.json')
    );
  }

  get version(): AppConfig {
    return this.config;
  }

  get showPanel(): boolean {
    return this.config.showVersionPanel === 'true';
  }

  /** Live-Abfrage aller Service-Versionen */
  fetchLiveVersions(): Observable<LiveVersionInfo[]> {
    const requests = Object.entries(this.config.services).map(
      ([name, url]) =>
        this.http
          .get<LiveVersionInfo>(`${url}/version`)
          .pipe(
            map((info) => ({ ...info, status: 'ok' as const })),
            catchError(() =>
              of({
                component: name,
                version: '?',
                systemVersion: '?',
                gitCommit: '?',
                status: 'unreachable' as const,
              })
            )
          )
    );
    return forkJoin(requests);
  }
}
```

### 6.5 APP_INITIALIZER

**`src/app/app.config.ts`**:

```typescript
import { APP_INITIALIZER, ApplicationConfig } from '@angular/core';
import { provideHttpClient } from '@angular/common/http';
import { ConfigService } from './config.service';

export function initApp(configService: ConfigService) {
  return () => configService.load();
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(),
    {
      provide: APP_INITIALIZER,
      useFactory: initApp,
      deps: [ConfigService],
      multi: true,
    },
  ],
};
```

### 6.6 Version-Panel Komponente

**`src/app/system-version-panel.component.ts`**:

```typescript
import { Component, inject } from '@angular/core';
import { SlicePipe } from '@angular/common';
import { ConfigService, LiveVersionInfo } from './config.service';

@Component({
  selector: 'app-system-version-panel',
  standalone: true,
  imports: [SlicePipe],
  template: `
    <div class="panel" [class.open]="open">
      <!-- Toggle Button -->
      <button class="toggle" (click)="open = !open">
        System v{{ config.version.systemVersion }}
        <span class="arrow">{{ open ? '▼' : '▲' }}</span>
      </button>

      @if (open) {
        <div class="content">
          <!-- Manifest (Soll-Zustand) -->
          <h4>Manifest (Soll)</h4>
          <table>
            <tr>
              <th>Komponente</th>
              <th>Version</th>
            </tr>
            @for (entry of manifestEntries; track entry[0]) {
              <tr>
                <td>{{ entry[0] }}</td>
                <td class="mono">{{ entry[1] }}</td>
              </tr>
            }
          </table>

          <!-- Live (Ist-Zustand) -->
          <h4>
            Live (Ist)
            <button class="refresh" (click)="loadLive()">↻</button>
          </h4>
          @if (liveVersions) {
            <table>
              <tr>
                <th>Komponente</th>
                <th>Version</th>
                <th>Commit</th>
                <th>Status</th>
              </tr>
              @for (svc of liveVersions; track svc.component) {
                <tr [class.mismatch]="isMismatch(svc)">
                  <td>{{ svc.component }}</td>
                  <td class="mono">{{ svc.version }}</td>
                  <td class="mono">{{ svc.gitCommit | slice:0:7 }}</td>
                  <td>
                    @if (svc.status === 'ok') { ✅ }
                    @else { ❌ }
                  </td>
                </tr>
              }
            </table>
          } @else {
            <p class="hint">Klick ↻ für Live-Abfrage</p>
          }
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
      color: #ccc;
      border-radius: 8px 8px 0 0;
      font-size: 12px;
      z-index: 9999;
      min-width: 380px;
      box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.3);
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }
    .toggle {
      width: 100%;
      padding: 8px 12px;
      background: #16213e;
      color: #0ff;
      border: none;
      cursor: pointer;
      font-family: monospace;
      font-size: 13px;
      border-radius: 8px 8px 0 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .toggle:hover {
      background: #1a2744;
    }
    .content {
      padding: 8px 12px 12px;
      max-height: 400px;
      overflow-y: auto;
    }
    h4 {
      color: #0ff;
      margin: 12px 0 4px;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      display: flex;
      align-items: center;
      gap: 4px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th {
      text-align: left;
      color: #666;
      font-weight: normal;
      padding: 3px 8px;
      font-size: 10px;
      text-transform: uppercase;
      border-bottom: 1px solid #333;
    }
    td {
      padding: 3px 8px;
    }
    .mono {
      font-family: 'SF Mono', 'Fira Code', monospace;
    }
    .mismatch {
      background: rgba(255, 50, 50, 0.15);
    }
    .mismatch td {
      color: #ff6b6b;
    }
    .refresh {
      background: none;
      border: none;
      color: #0ff;
      cursor: pointer;
      font-size: 16px;
      padding: 0 4px;
    }
    .refresh:hover {
      color: #fff;
    }
    .hint {
      color: #555;
      font-style: italic;
      margin: 4px 0;
    }
  `],
})
export class SystemVersionPanelComponent {
  config = inject(ConfigService);
  open = false;
  liveVersions: LiveVersionInfo[] | null = null;

  get manifestEntries(): [string, string][] {
    return Object.entries(this.config.version.components);
  }

  loadLive(): void {
    this.config.fetchLiveVersions().subscribe((versions) => {
      this.liveVersions = versions;
    });
  }

  isMismatch(svc: LiveVersionInfo): boolean {
    const expected = this.config.version.components[svc.component];
    return expected != null && expected !== svc.version;
  }
}
```

### 6.7 Einbindung in App-Component

**`src/app/app.component.ts`**:

```typescript
import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { SystemVersionPanelComponent } from './system-version-panel.component';
import { ConfigService } from './config.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, SystemVersionPanelComponent],
  template: `
    <router-outlet />
    @if (config.showPanel) {
      <app-system-version-panel />
    }
  `,
})
export class AppComponent {
  config = inject(ConfigService);
}
```

### 6.8 Ergebnis im Browser

```
┌──────────────────────────────────────────────┐
│  System v42                                ▼ │
├──────────────────────────────────────────────┤
│  MANIFEST (SOLL)                             │
│  Komponente            Version               │
│  service-auth          2.1.0                 │
│  service-orders        3.4.1                 │
│  service-payments      1.8.0                 │
│  service-gateway       5.0.2                 │
│  frontend              1.5.0                 │
│                                              │
│  LIVE (IST)                              ↻   │
│  Komponente        Version  Commit  Status   │
│  service-auth      2.1.0    f4e2a1b   ✅     │
│  service-orders    3.4.1    a1b2c3d   ✅     │
│  service-payments  1.7.0    c3d4e5f   ❌     │  ← Mismatch!
│  service-gateway   5.0.2    b2c3d4e   ✅     │
└──────────────────────────────────────────────┘
```

---

## 7. Rückverfolgbarkeit in Testumgebungen

### Schnellabfrage: „Was läuft gerade in Staging?"

```bash
#!/bin/bash
echo "=== Deployed Services ==="
for svc in $(kubectl get deployments -n staging -o name); do
  IMAGE=$(kubectl get $svc -n staging -o jsonpath='{.spec.template.spec.containers[0].image}')
  echo "$svc → $IMAGE"
done

echo ""
echo "=== System-Manifest ==="
cd system-manifest
git show main:versions.json | jq .
```

### Historische Abfrage: „Was lief am 15. Januar?"

```bash
# Im system-manifest Repo:
git log --before="2026-01-16" --format="%h %s" -1
# → abc1234 v38: service-auth → 2.0.5

git show system-v38:versions.json | jq .
```

### Diff zwischen zwei System-Versionen

```bash
# Was hat sich zwischen v38 und v42 geändert?
diff <(git show system-v38:versions.json | jq '.components') \
     <(git show system-v42:versions.json | jq '.components')
```

---

## 8. Optionale Erweiterungen

### Slack-Notification bei jedem Bump

Am Ende von `bump-system-version.sh` hinzufügen:

```bash
if [ -n "$SLACK_WEBHOOK" ]; then
  curl -s -X POST "$SLACK_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{
      \"text\": \"🚀 System *v${NEW_VERSION}* – ${COMPONENT_NAME} → ${COMPONENT_VERSION} (${GIT_COMMIT})\"
    }"
fi
```

### Prod-Deployment separat (bewusste Entscheidung)

Test ist vollautomatisch, Prod bleibt kontrolliert:

```bash
# Review: Was geht raus?
cd system-manifest
git show system-v48:versions.json | jq .

# Diff zu aktuell deployed:
diff <(git show system-v45:versions.json | jq '.components') \
     <(git show system-v48:versions.json | jq '.components')

# → Approval → Deploy
```

### Redundanz & Ausfallsicherheit

Wenn das Manifest-Repo gelöscht würde, können die System-Versionen aus den Tags der Component-Repos rekonstruiert werden:

```bash
# Alle system-v* Tags eines Repos auflisten:
git tag -l 'system-v*' --sort=-version:refname

# Rekonstruktion: welche Komponenten-Version gehört zu system-v42?
for repo in service-auth service-orders service-payments service-gateway frontend; do
  cd /repos/$repo
  VERSION=$(git tag --points-at $(git rev-list -n1 system-v42) | grep -v system)
  echo "$repo: $VERSION"
  cd ..
done
```
