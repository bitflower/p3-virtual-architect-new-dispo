# Embedding New Dispo Frontend - Effort Analysis

**Date:** 2026-03-12
**Status:** Exploration

---

## Original User Input

> Hi Matthias, Frage: Hast du ne Idee wie aufwendig es wäre, das New Dispo Frontend in eine andere Seite zu embedden? Sprich Navigation rauslösen, Auth über n globalen M365 Login

---

## Summary

Aufwandsanalyse für das Embedding des New Dispo Frontends in eine andere Anwendung mit:
- Entfernung der Navigation (Sidebar)
- ~~Integration von M365 Authentication (statt Keycloak)~~ → **ENTFÄLLT: Keycloak ist bereits mit EntraID synchronisiert!**

**Geschätzter Aufwand: NIEDRIG (1-2 Tage)** ✅

**UPDATE nach Klärung:**
- Auth-Migration NICHT nötig (Keycloak ↔ EntraID Sync bereits vorhanden)
- Embedding-Implementierung macht ein anderes Team
- Nur Frontend-Anpassungen für "headless mode" nötig

Die einzige Herausforderung:
1. Navigation optional/entfernbar machen (Environment-Flag)

**Empfehlung: IFRAME** (einfachste Lösung)

---

## VEREINFACHTE LÖSUNG (nach Klärung) ⭐

### Was sich ändert:
✅ **Keine Auth-Migration nötig!** Keycloak bleibt, da bereits mit EntraID synchronisiert
✅ **Embedding macht anderes Team** - wir liefern nur embeddable Frontend
✅ **Iframe-Ansatz** - einfachste Integration, keine Build-Änderungen

### Was wir tun müssen:

**1. "Headless Mode" Flag einführen (0.5 Tage)**
```typescript
// environment.ts
export const environment = {
  embeddedMode: false,  // neu
  // ... existing config
}
```

**2. Navigation conditional machen (0.5 Tage)**
```html
<!-- app.component.html -->
<mat-sidenav-container>
  @if (!embeddedMode) {
    <mat-sidenav #snav [opened]="true">
      <!-- Sidebar Navigation -->
    </mat-sidenav>
  }
  <mat-sidenav-content>
    <lib-header [headerContent]="headerTemplate" />
    <router-outlet />
    <lib-footer [footerContent]="footerTemplate" />
  </mat-sidenav-content>
</mat-sidenav-container>
```

**3. Optional: Header/Footer auch hideable (0.5 Tage)**
- Falls Parent-App eigene Header/Footer hat
- Gleiche Conditional Logic

**4. Testing (0.5 Tage)**
- Mit/ohne Navigation
- Iframe-Integration testen

### Total: **1-2 Arbeitstage** 🎉

### Iframe Integration (für Parent-Team):
```html
<!-- Parent App macht dann: -->
<iframe
  src="https://new-dispo.nagel.com/?embedded=true"
  width="100%"
  height="100%"
  style="border: none;">
</iframe>
```

---

## Analysis (Original - teilweise überholt)

### Aktuelle Architektur

**Framework:** Angular 19 (Standalone Components)

**Kern-Komponenten:**
- `app.component.ts` - Root Component mit Mat-Sidenav Container
- `app.component.html` - Layout mit Sidebar, Header, Footer, Router-Outlet
- Navigation via Material Sidenav (`mat-sidenav-container`)

**Authentifizierung (aktuell):**
- Keycloak-basiert (momentan für lokale Development deaktiviert)
- Libraries: `keycloak-angular` 19.0.2, `keycloak-js` 25.0.1
- Auth-Guard auf allen Routes
- Token-Refresh Mechanismus (aktuell auskommentiert)

### Benötigte Änderungen

#### 1. Navigation entfernen/optional machen (Aufwand: Mittel)

**Aktueller Stand:**
- Gesamte App ist in `mat-sidenav-container` gewrapped
- Sidebar enthält: Header, Nav-Links, Collapse-Button
- Datei: `app.component.html:1-25`

**Lösungsansätze:**

**Option A: Conditional Rendering (empfohlen)**
```typescript
// Neue Konfiguration für Embedding-Modus
export const environment = {
  embeddedMode: true/false,
  showNavigation: true/false,
  showHeader: true/false,
  showFooter: true/false
}
```

Änderungen:
- `app.component.html`: Wrapping von `<mat-sidenav>` in `@if (!embeddedMode)`
- `app.component.ts`: Embedding-Mode Flag auswerten
- Template anpassen für standalone router-outlet

**Option B: Separate Embedded Component**
- Neue `embedded-app.component.ts` erstellen
- Nur `<router-outlet>` ohne Layout
- Separate Bootstrap-Konfiguration

**Aufwand:** 0.5-1 Tag

#### 2. M365 Authentication integrieren (Aufwand: Mittel-Hoch)

**Keycloak → MSAL Migration:**

**Zu ersetzende Komponenten:**
- `libs/nagel-services/src/lib/keycloakService/keycloak.service.ts`
- `libs/nagel-services/src/lib/authGuardService/auth-guard.service.ts`
- `app.config.ts`: APP_INITIALIZER für Keycloak

**Neue Abhängigkeiten:**
```json
"@azure/msal-angular": "^3.0.x",
"@azure/msal-browser": "^3.0.x"
```

**MSAL Konfiguration benötigt:**
- Client ID
- Tenant ID
- Redirect URIs
- Scopes für API-Zugriff

**Änderungen:**

1. **Neuer MSAL Service** (`msal.service.ts`):
   - Init mit M365 Config
   - Token-Acquisition
   - Silent Token Refresh
   - Logout

2. **Auth Guard Anpassung**:
   - MSAL Redirect/Popup Flow
   - Token-Validierung
   - Role-Mapping (falls benötigt)

3. **HTTP Interceptor**:
   - Bearer Token aus MSAL
   - Bestehende: `traceIdInterceptor`, `loggerInterceptor`

4. **App Initialization**:
```typescript
// app.config.ts Änderung
{
  provide: APP_INITIALIZER,
  useFactory: initializeMsal,
  multi: true,
  deps: [MsalService]
}
```

**Aufwand:** 1.5-2 Tage

#### 3. Embedding-Strategie (Aufwand: Mittel)

**Option A: Iframe (einfacher, mehr Isolation)**

Vorteile:
- Vollständige Style-Isolation
- Einfache Integration
- Separate Security Context

Nachteile:
- Communication über postMessage
- Separate Authentifizierung nötig (Cookie-Sharing problematisch)
- Performance Overhead

**Option B: Web Component / Angular Element (empfohlen)**

Vorteile:
- Shared Authentication möglich
- Bessere Performance
- Native Integration

Nachteile:
- CSS Isolation aufwendiger
- Build-Konfiguration komplexer

**Änderungen für Web Component:**
```typescript
// main.ts Anpassung
import { createCustomElement } from '@angular/elements';

const element = createCustomElement(AppComponent, {
  injector: this.injector
});
customElements.define('new-dispo-app', element);
```

**Build Config:**
- `ng-packagr` oder Custom Builder
- Single Bundle Output
- Polyfills für Web Components

**Aufwand:** 1-1.5 Tage

#### 4. Routing in Embedded Context (Aufwand: Klein-Mittel)

**Herausforderungen:**
- Base HREF Management
- Deep-Linking
- Browser History vs. Hash Routing

**Anpassungen:**

1. **app.config.ts**:
```typescript
provideRouter(routes,
  withHashLocation(), // oder
  withInMemoryScrolling()
)
```

2. **NavigationService Anpassung**:
- `navigation.service.ts:14-22` nutzt bereits `platformLocation.getBaseHrefFromDOM()`
- Evtl. Anpassung für embedded context

**Aufwand:** 0.5 Tag

#### 5. Styling & CSS Isolation (Aufwand: Klein)

**Aktueller Stand:**
- Angular Material Theme
- Component-scoped Styles
- Global Styles in `styles.scss`

**Bei Web Component:**
- Shadow DOM aktivieren (volle Isolation)
- Oder: CSS-Prefix Strategy

**Bei Iframe:**
- Keine Änderung nötig

**Aufwand:** 0.5 Tag

---

## Source Code Evidence

### App Structure
- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/app.component.ts:75-167`
  - Root component mit Sidenav-Container
  - Keycloak Service Dependency (Zeile 87)
  - Token-Refresh Logic (auskommentiert, Zeile 121-153)

- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/app.component.html:1-25`
  - Mat-Sidenav Layout
  - Sidebar mit Navigation Links
  - Header, Footer, Router-Outlet

### Authentication
- `Code/Disposition-Frontend/libs/nagel-services/src/lib/keycloakService/keycloak.service.ts:1-77`
  - Keycloak Service mit isInitialized Flag
  - Aktuell alle Methoden mit DISABLED Guards

- `Code/Disposition-Frontend/libs/nagel-services/src/lib/authGuardService/auth-guard.service.ts:1-60`
  - AuthGuard immer `return Promise.resolve(true)`
  - Original Keycloak Logic auskommentiert

- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/app.config.ts:20-43`
  - Keycloak Initialization auskommentiert (Zeile 35-41)

### Navigation
- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/configuration/definitions/navLinks.ts:1-26`
  - 3 Main Routes: Planning, Transport, Customer Communication
  - Dev-Mode Test Route

- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/app.routes.ts:1-64`
  - AuthGuard auf allen Routes
  - Role-based Access: `['manage-account-links']`

---

## Findings

### Positive Aspekte
1. **Auth bereits abstrahiert**: Keycloak ist sauber über Service gekapselt → einfacher zu ersetzen
2. **Standalone Components**: Angular 19 → modernere Architektur, besser für Embedding
3. **Modularer Aufbau**: Libs-Struktur (`@nagel-services`, `@nagel-components`) → gute Separation of Concerns
4. **Auth aktuell disabled**: Bedeutet Production-Code ist vorbereitet aber nicht aktiv → weniger Breaking Changes bei Migration

### Herausforderungen
1. **Navigation tief integriert**: Komplettes App-Layout ist um Sidenav gebaut
2. **Keine bestehende Embed-Strategie**: Alles ist für Standalone App designed
3. **Keycloak → MSAL**: Komplett anderes Auth-Paradigma (OIDC vs. MSAL Flow)
4. **Testing aufwendig**: Embedded Mode muss in beiden Contexts getestet werden

### Risiken
1. **Shared State**: Wenn Parent-App auch Angular nutzt → mögliche Konflikte
2. **Version Conflicts**: Angular Material, Dependencies
3. **Performance**: Bei Web Components → Größerer Bundle

---

## Aufwandsschätzung (detailliert)

### AKTUALISIERT nach Klärung ✅

| Task | Aufwand | Priorität | Komplexität |
|------|---------|-----------|-------------|
| Environment Flag für embeddedMode | 0.25 Tag | Hoch | Niedrig |
| Navigation conditional machen | 0.5 Tag | Hoch | Niedrig |
| Header/Footer optional (falls gewünscht) | 0.25 Tag | Mittel | Niedrig |
| Query Parameter Support (?embedded=true) | 0.25 Tag | Mittel | Niedrig |
| Testing (mit/ohne Navigation) | 0.5 Tag | Hoch | Niedrig |
| Dokumentation | 0.25 Tag | Niedrig | Niedrig |
| **GESAMT** | **1.5-2 Tage** | | |

**Konservative Schätzung: 2 Arbeitstage** ✅
**Optimistische Schätzung: 1 Arbeitstag** ✅

~~**ALTE Schätzung (wenn Auth-Migration nötig gewesen wäre): 6-8 Tage**~~

---

## Questions/Open Items

### ✅ GEKLÄRT:
1. ~~**M365 Auth Integration**~~ → **Keycloak bleibt, ist bereits mit EntraID synchronisiert**
2. ~~**Embedding-Implementation**~~ → **Macht das Parent-Team**
3. ~~**Iframe vs Web Component**~~ → **Iframe (einfacher)**

### ⚠️ NOCH OFFEN:

1. **UI/UX Embedded Mode**
   - Soll Header auch ausgeblendet werden? (Profilbild, etc.)
   - Soll Footer auch ausgeblendet werden?
   - Oder nur Sidebar Navigation?

2. **Feature-Scope**
   - Alle drei Bereiche embeddable? (Planning, Transport, Customer Communication)
   - Oder nur einzelne Seiten?
   - Deep-Linking zu spezifischen Aufträgen? (`/order-details/123`)

3. **Parent-App Details**
   - Welche App ist das? (für Dokumentation)
   - Gleiche Domain oder CORS zu beachten?
   - Cookie-Sharing für Auth möglich?

4. **Deployment**
   - Separate Deployment-Variante oder Query-Parameter-gesteuert?
   - Environment-Variable oder Runtime-Config?

5. **Timeline**
   - Wann wird das benötigt?
   - Pilotphase oder direkt Production?

---

## Iframe vs Web Component - Vergleich

| Kriterium | Iframe ⭐ | Web Component |
|-----------|---------|---------------|
| **Implementierungsaufwand (unsere Seite)** | **1-2 Tage** | 3-4 Tage |
| **Implementierungsaufwand (Parent)** | Trivial (`<iframe>` Tag) | Mittel (Bundle einbinden) |
| **CSS Isolation** | ✅ Perfekt (automatic) | Manuell (Shadow DOM) |
| **Security Isolation** | ✅ Separate Context | ⚠️ Shared Context |
| **Authentication** | Shared via Cookie Domain | Shared via Service |
| **Performance** | Gut (separate Paint) | Besser (shared Rendering) |
| **Communication** | postMessage | Direct JS |
| **Deployment** | ✅ Unabhängig | Gekoppelt |
| **Versioning** | ✅ Einfach | Komplexer |
| **Deep Linking** | ✅ URL-basiert | Custom Routing |
| **Browser Support** | ✅ Universal | Modern Browsers |
| **Build-Änderungen** | ❌ Keine | ✅ Ja (ng-packagr) |

### Empfehlung: **IFRAME** ⭐

**Gründe:**
- Minimal invasiv (keine Build-Änderungen)
- Perfekte Isolation (CSS, Security)
- Unabhängiges Deployment
- Triviale Integration für Parent-Team
- Auth funktioniert via Cookie-Sharing (gleiche Domain)
- Aufwand: 1-2 Tage statt 3-4 Tage

## Empfohlener Ansatz (AKTUALISIERT)

### Phase 1: Environment Config (0.5 Tage)
1. `embeddedMode` Flag in environment.ts
2. Query Parameter Support: `?embedded=true` → setzt Flag

### Phase 2: UI Anpassungen (0.5 Tage)
1. Navigation conditional rendern
2. Optional: Header/Footer conditional
3. Styling check (evtl. volle Breite wenn no sidebar)

### Phase 3: Testing & Dokumentation (0.5 Tage)
1. Lokales Testing mit `?embedded=true`
2. Iframe-Integration Demo
3. Dokumentation für Parent-Team schreiben

**Total: 1.5 Arbeitstage** ✅

### Implementation Beispiel

**1. environment.ts:**
```typescript
export const environment = {
  production: true,
  embeddedMode: false, // Default: standalone
  // ... existing
};
```

**2. app.component.ts:**
```typescript
export class AppComponent implements OnInit {
  embeddedMode = environment.embeddedMode;

  ngOnInit() {
    // Check query param
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('embedded') === 'true') {
      this.embeddedMode = true;
    }
  }
}
```

**3. app.component.html:**
```html
<mat-sidenav-container>
  @if (!embeddedMode) {
    <mat-sidenav #snav [opened]="true">
      <!-- Navigation -->
    </mat-sidenav>
  }
  <mat-sidenav-content>
    @if (!embeddedMode) {
      <lib-header [headerContent]="headerTemplate" />
    }
    <router-outlet />
    @if (!embeddedMode) {
      <lib-footer [footerContent]="footerTemplate" />
    }
  </mat-sidenav-content>
</mat-sidenav-container>
```

**4. Parent-Team Integration:**
```html
<iframe
  src="https://new-dispo.nagel.com/?embedded=true"
  width="100%"
  height="100%"
  style="border: none;"
  title="New Dispo">
</iframe>
```

---

## Related Files

- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/app.component.*`
- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/app.config.ts`
- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/app.routes.ts`
- `Code/Disposition-Frontend/libs/nagel-services/src/lib/keycloakService/keycloak.service.ts`
- `Code/Disposition-Frontend/libs/nagel-services/src/lib/authGuardService/auth-guard.service.ts`
- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/services/navigation.service.ts`
- `Code/Disposition-Frontend/apps/nagel-cal-disposition/src/app/configuration/definitions/navLinks.ts`

---

## Related User Stories/Tasks

Noch keine zugeordnet - Anfrage zur Klärung der Requirements und Entscheidung über Approach.

---

## TL;DR - Executive Summary 🎯

**Frage:** New Dispo Frontend in andere Seite embedden (Navigation weg, globaler M365 Login)

**Antwort:**
- ✅ **Sehr einfach machbar!**
- ✅ **Aufwand: 1-2 Arbeitstage**
- ✅ **Keine Auth-Migration nötig** (Keycloak ↔ EntraID Sync bereits da)
- ✅ **Iframe-Lösung empfohlen** (einfachste Integration)

**Was zu tun ist:**
1. Environment Flag `embeddedMode` einführen
2. Navigation/Header/Footer conditional rendern
3. Query Parameter Support (`?embedded=true`)
4. Testen & dokumentieren

**Was das Parent-Team macht:**
```html
<iframe src="https://new-dispo.nagel.com/?embedded=true" />
```

**Risiko:** Niedrig ✅
**Komplexität:** Niedrig ✅
**ROI:** Hoch ✅
