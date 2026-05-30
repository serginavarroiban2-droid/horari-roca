// Edge Function: sync-google-calendar (versió simplificada)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const serviceAccountJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON not configured");
    }
    const credentials = JSON.parse(serviceAccountJson);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const body = await req.json();
    const impersonateEmail = Deno.env.get("GOOGLE_IMPERSONATE_EMAIL");
    const accessToken = await getAccessToken(credentials, impersonateEmail);

    if (body.mode === "setup_calendar") {
      // Crear calendari per treballador
      const calRes = await fetch("https://www.googleapis.com/calendar/v3/calendars", {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          summary: `Horari - ${body.worker_name}`,
          timeZone: "Europe/Madrid",
        }),
      });

      if (!calRes.ok) throw new Error(await calRes.text());
      const calendar = await calRes.json();

      // Compartir amb treballador (només lectura)
      await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendar.id}/acl`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({ role: "reader", scope: { type: "user", value: body.worker_email } }),
      });

      // Guardar a BD
      await supabase.from("worker_calendars").upsert({
        worker_name: body.worker_name,
        worker_email: body.worker_email,
        google_calendar_id: calendar.id,
        sync_enabled: true,
        sync_status: "synced",
        updated_at: new Date().toISOString(),
      }, { onConflict: "worker_name" });

      // Sincronització inicial immediata
      await syncShiftsForWorker(supabase, accessToken, body.worker_name, calendar.id);

      return new Response(JSON.stringify({ success: true, calendarId: calendar.id }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

    } else if (body.mode === "update_email") {
      // Actualitzar email treballador
      const { data: currentConfig } = await supabase
        .from("worker_calendars")
        .select("*")
        .eq("worker_name", body.worker_name)
        .single();

      if (!currentConfig) throw new Error("Worker config not found");
      const calendarId = currentConfig.google_calendar_id;

      // 1. Afegir nou email al calendari
      await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/acl`, {
        method: "POST",
        headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({ role: "reader", scope: { type: "user", value: body.worker_email } }),
      });

      // 2. Intentar esborrar l'antic (si és diferent)
      if (currentConfig.worker_email && currentConfig.worker_email !== body.worker_email) {
        // Primer cal trobar l'ID de la regla ACL antiga.
        // Llista les regles ACL
        const aclRes = await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/acl`, {
          headers: { Authorization: `Bearer ${accessToken}` }
        });
        if (aclRes.ok) {
          const aclData = await aclRes.json();
          const oldRule = aclData.items.find((rule: any) => rule.scope.type === 'user' && rule.scope.value === currentConfig.worker_email);
          if (oldRule) {
            await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/acl/${oldRule.id}`, {
              method: "DELETE",
              headers: { Authorization: `Bearer ${accessToken}` }
            });
          }
        }
      }

      // 3. Actualitzar BD
      await supabase.from("worker_calendars").update({
        worker_email: body.worker_email,
        updated_at: new Date().toISOString(),
      }).eq("worker_name", body.worker_name);

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

    } else if (body.mode === "full_sync") {
      // Sincronitzar torns
      let synced = 0;
      const { data: configs } = await supabase.from("worker_calendars").select("*").eq("sync_enabled", true);

      for (const config of configs || []) {
        if (body.worker_name && config.worker_name !== body.worker_name) continue;

        await syncShiftsForWorker(supabase, accessToken, config.worker_name, config.google_calendar_id);
        synced++;
      }

      return new Response(JSON.stringify({ success: true, synced }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Invalid mode" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function syncShiftsForWorker(supabase: any, accessToken: string, workerName: string, calendarId: string) {
  const today = new Date();
  const futureRange = new Date(today);
  futureRange.setDate(today.getDate() + 90); // Sincronitzem 90 dies (aprox 3 mesos) per seguretat

  const startDateStr = today.toISOString().slice(0, 10);
  const endDateStr = futureRange.toISOString().slice(0, 10);

  // 1. Obtenir Shifts de Supabase
  const { data: shifts, error: shiftError } = await supabase.from("shifts").select("*")
    .eq("worker_name", workerName)
    .gte("date", startDateStr)
    .lte("date", endDateStr);

  if (shiftError) throw shiftError;

  // 2. Obtenir Events existents a Google Calendar per evitar duplicats
  // Convertim range a ISO amb timeZone si cal, però Google accepta 'Z'
  const timeMin = new Date(startDateStr).toISOString();
  // +1 dia per cobrir tot l'últim dia
  const timeMax = new Date(futureRange.getTime() + 86400000).toISOString();

  const googleEvents = await listEvents(accessToken, calendarId, timeMin, timeMax);

  // 3. Processar Shifts
  for (const shift of shifts || []) {
    const shiftStartISO = `${shift.date}T${shift.start_time}`; // Prefix esperat ex: 2026-02-06T08:00:00
    // Nota: Google pot retornar '2026-02-06T08:00:00+01:00'. Comparem l'inici.

    // Buscar events coincidents (mateix start time)
    const matches = googleEvents.filter((ev: any) =>
      ev.start.dateTime && ev.start.dateTime.startsWith(shiftStartISO)
    );

    let eventId = null;

    if (matches.length === 0) {
      // CREATE
      const newEvent = await createEvent(accessToken, calendarId, shift);
      eventId = newEvent.id;
    } else {
      // UPDATE el primer
      const first = matches[0];
      eventId = first.id;
      // Actualitzem per si ha canviat la nota o l'hora final
      await patchEvent(accessToken, calendarId, eventId, shift);

      // DELETE duplicats (El problema que reporta l'usuari)
      if (matches.length > 1) {
        for (let i = 1; i < matches.length; i++) {
          await deleteEvent(accessToken, calendarId, matches[i].id);
        }
      }
    }

    // Actualitzar taula de mapping (opcional però recomanable)
    if (eventId) {
      // Mirem si existeix per index (shift_date, worker_name, start_time, end_time)
      const { data: existing } = await supabase.from("calendar_events_sync")
        .select("id")
        .eq("shift_date", shift.date)
        .eq("worker_name", shift.worker_name)
        .eq("start_time", shift.start_time)
        .eq("end_time", shift.end_time)
        .maybeSingle();

      if (existing) {
        await supabase.from("calendar_events_sync").update({
          google_event_id: eventId,
          last_synced: new Date().toISOString(),
          sync_action: matches.length === 0 ? 'create' : 'update'
        }).eq("id", existing.id);
      } else {
        await supabase.from("calendar_events_sync").insert({
          shift_date: shift.date,
          worker_name: shift.worker_name,
          start_time: shift.start_time,
          end_time: shift.end_time,
          lane: shift.lane,
          google_event_id: eventId,
          calendar_id: calendarId,
          last_synced: new Date().toISOString(),
          sync_action: matches.length === 0 ? 'create' : 'update'
        });
      }
    }

    // Treure els processats de la llista googleEvents per identificar 'orfes'
    matches.forEach((m: any) => {
      const idx = googleEvents.indexOf(m);
      if (idx > -1) googleEvents.splice(idx, 1);
    });
  }

  // 4. Netejar Orfes (Events a Google que no tenen shift corresponent a BD)
  // Això resol el cas "He esborrat el shift a l'app però segueix al calendari"
  // Ara incloem 'Roca' i 'Rambla' a més de 'Torn'
  for (const ev of googleEvents) {
    const sum = ev.summary || "";
    if (sum === "Torn" || sum.startsWith("Torn") || sum === "Roca" || sum === "Rambla") {
      await deleteEvent(accessToken, calendarId, ev.id);
    }
  }
}

// Helpers Google API
async function listEvents(accessToken: string, calendarId: string, timeMin: string, timeMax: string) {
  const params = new URLSearchParams({
    timeMin: timeMin,
    timeMax: timeMax,
    singleEvents: "true",
    orderBy: "startTime", // Ensure correct order if useful, but optional
    maxResults: "2500" // Suficient per 45 dies
  });

  const res = await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events?${params}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!res.ok) {
    console.error("Error listing events:", await res.text());
    return [];
  }
  const data = await res.json();
  return data.items || [];
}

async function createEvent(accessToken: string, calendarId: string, shift: any) {
  let endDate = shift.date;
  if (shift.end_time < shift.start_time) {
    const d = new Date(shift.date);
    d.setDate(d.getDate() + 1);
    endDate = d.toISOString().split('T')[0];
  }

  // 0-3 = Roca, 4 = Rambla
  const locationName = (shift.lane >= 4) ? "Rambla" : "Roca";

  const res = await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      summary: locationName,
      description: shift.note || "",
      start: { dateTime: `${shift.date}T${shift.start_time}`, timeZone: "Europe/Madrid" },
      end: { dateTime: `${endDate}T${shift.end_time}`, timeZone: "Europe/Madrid" },
    }),
  });
  if (!res.ok) throw new Error("Error creating event: " + await res.text());
  return await res.json();
}

async function patchEvent(accessToken: string, calendarId: string, eventId: string, shift: any) {
  let endDate = shift.date;
  if (shift.end_time < shift.start_time) {
    const d = new Date(shift.date);
    d.setDate(d.getDate() + 1);
    endDate = d.toISOString().split('T')[0];
  }

  const locationName = (shift.lane >= 4) ? "Rambla" : "Roca";

  await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events/${eventId}`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      summary: locationName,
      description: shift.note || "",
      start: { dateTime: `${shift.date}T${shift.start_time}`, timeZone: "Europe/Madrid" },
      end: { dateTime: `${endDate}T${shift.end_time}`, timeZone: "Europe/Madrid" },
    }),
  });
}

async function deleteEvent(accessToken: string, calendarId: string, eventId: string) {
  await fetch(`https://www.googleapis.com/calendar/v3/calendars/${calendarId}/events/${eventId}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${accessToken}` }
  });
}

async function getAccessToken(creds: any, impersonateEmail?: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" })).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const payloadData: any = {
    iss: creds.client_email,
    scope: "https://www.googleapis.com/auth/calendar",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  if (impersonateEmail) {
    payloadData.sub = impersonateEmail;
  }

  const payload = btoa(JSON.stringify(payloadData)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const key = creds.private_key.replace(/\\n/g, "\n");
  const pemContent = key.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "").replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContent), c => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey("pkcs8", binaryKey, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", cryptoKey, new TextEncoder().encode(`${header}.${payload}`));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${header}.${payload}.${sigB64}`,
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("Failed to get token: " + JSON.stringify(data));
  return data.access_token;
}
