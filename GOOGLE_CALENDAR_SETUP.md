# 🔧 Guia Configuració Google Cloud Platform

## 1. Crear Projecte a Google Cloud Console

1. Ves a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nou projecte o selecciona un existent
3. Anota el **Project ID**

## 2. Activar Google Calendar API

1. Menú ☰ → **APIs & Services** → **Library**
2. Cerca "Google Calendar API"
3. Clica **Enable**

## 3. Crear Service Account

1. Menú ☰ → **IAM & Admin** → **Service Accounts**
2. Clica **+ Create Service Account**
3. Nom: `horari-calendar-sync`
4. Clica **Create and Continue** → **Done**
5. Clica a la nova service account → **Keys** → **Add Key** → **Create new key** → **JSON**
6. Desa el fitxer JSON (conté les credencials)

## 4. Configurar Domain-Wide Delegation (Opcional - Per Workspace)

Si vols que el service account pugui crear calendaris per usuaris del domini:

1. A la Service Account, clica **Edit** → Activa **Enable Google Workspace Domain-wide Delegation**
2. Anota el **Client ID**
3. A l'Admin Console de Google Workspace:
   - **Security** → **API Controls** → **Manage Domain Wide Delegation**
   - **Add new** amb el Client ID i scope: `https://www.googleapis.com/auth/calendar`

## 5. Afegir Secrets a Supabase

1. Ves al teu projecte de Supabase → **Settings** → **Edge Functions**
2. Afegeix el secret:
   - Nom: `GOOGLE_SERVICE_ACCOUNT_JSON`
   - Valor: Tot el contingut del fitxer JSON descarregat (copiar/enganxar)

## 6. Executar Migració SQL

Executa el contingut de `supabase/migrations/20260205_google_calendar_sync.sql` a la teva base de dades:
- Ves a **SQL Editor** al dashboard de Supabase
- Enganxa i executa l'SQL

## 7. Desplegar Edge Function

```bash
cd horari-roca
npx supabase functions deploy sync-google-calendar --project-ref zwxismquyhyeufdmtgsw
```

## 8. Verificació

1. Entra a l'app com admin
2. Clica el botó **📅 Google Calendar**
3. Introdueix l'email d'un treballador
4. Clica **⚙️ Configurar**
5. Verifica que el calendari s'ha creat i el treballador rep la invitació

---

> **Nota:** El treballador ha d'acceptar la invitació del calendari per veure'l a Google Calendar.
