// Bauakte · Push-Versand
// Zwei Betriebsarten:
//   {"modus":"sofort","id":123}  -> einzelne Änderung sofort melden (per DB-Trigger)
//   {"modus":"buendeln"}         -> nach 10 Min Ruhe die gesammelten Änderungen melden (per Zeitplan)
//
// Benötigte Secrets (Dashboard -> Edge Functions -> Secrets):
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT, PUSH_SECRET
// SUPABASE_URL und SUPABASE_SERVICE_ROLE_KEY stellt Supabase automatisch bereit.

import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const RUHE_MINUTEN = 10;                       // Bündel-Fenster
const EMPFAENGER = ["isabella2", "tommy2"];    // nur diese beiden bekommen Meldungen

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT") ?? "mailto:bauakte@example.com",
  Deno.env.get("VAPID_PUBLIC_KEY")!,
  Deno.env.get("VAPID_PRIVATE_KEY")!,
);

async function sende(anEmpfaenger: string[], titel: string, text: string, tag: string) {
  if (!anEmpfaenger.length) return 0;
  const { data: geraete } = await sb
    .from("push_geraete")
    .select("endpoint, subscription, benutzer")
    .in("benutzer", anEmpfaenger);

  let ok = 0;
  for (const g of geraete ?? []) {
    try {
      await webpush.sendNotification(
        g.subscription,
        JSON.stringify({ titel, text, tag }),
      );
      ok++;
    } catch (err) {
      // Abgelaufene Anmeldung (404/410) aufräumen
      const code = (err as { statusCode?: number })?.statusCode;
      if (code === 404 || code === 410) {
        await sb.from("push_geraete").delete().eq("endpoint", g.endpoint);
      } else {
        console.error("Push fehlgeschlagen:", code, String(err));
      }
    }
  }
  return ok;
}

const empfaengerAusser = (actor: string) => EMPFAENGER.filter((e) => e !== actor);

Deno.serve(async (req) => {
  if (req.headers.get("x-push-secret") !== Deno.env.get("PUSH_SECRET")) {
    return new Response("nicht erlaubt", { status: 401 });
  }

  let body: { modus?: string; id?: number } = {};
  try { body = await req.json(); } catch { /* leer */ }

  const grenze = new Date(Date.now() - RUHE_MINUTEN * 60_000).toISOString();

  // ---------- SOFORT ----------
  if (body.modus === "sofort" && body.id) {
    const { data: zeile } = await sb
      .from("aenderungen")
      .select("id, actor, actor_label, beschreibung, created_at, gesendet")
      .eq("id", body.id)
      .maybeSingle();
    if (!zeile || zeile.gesendet) return Response.json({ ok: true, uebersprungen: true });

    // Gab es zu diesem Nutzer in den letzten 10 Minuten schon eine Meldung?
    const { count } = await sb
      .from("aenderungen")
      .select("id", { count: "exact", head: true })
      .eq("actor", zeile.actor)
      .eq("gesendet", true)
      .gte("created_at", grenze);

    if ((count ?? 0) > 0) {
      // Nein, nicht sofort melden — wird später gebündelt.
      return Response.json({ ok: true, gebuendelt: true });
    }

    const wer = zeile.actor_label || zeile.actor;
    await sende(
      empfaengerAusser(zeile.actor),
      "Bauakte",
      `${wer} ${zeile.beschreibung}`,
      "bauakte-sofort",
    );
    await sb.from("aenderungen").update({ gesendet: true }).eq("id", zeile.id);
    return Response.json({ ok: true, sofort: true });
  }

  // ---------- BÜNDELN ----------
  if (body.modus === "buendeln") {
    const { data: offen } = await sb
      .from("aenderungen")
      .select("id, actor, actor_label, created_at")
      .eq("gesendet", false);

    const proActor = new Map<string, { ids: number[]; letzte: string; label: string }>();
    for (const z of offen ?? []) {
      const e = proActor.get(z.actor) ?? { ids: [], letzte: z.created_at, label: z.actor_label || z.actor };
      e.ids.push(z.id);
      if (z.created_at > e.letzte) e.letzte = z.created_at;
      proActor.set(z.actor, e);
    }

    let versendet = 0;
    for (const [actor, e] of proActor) {
      if (e.letzte > grenze) continue;            // noch keine 10 Min Ruhe
      const anzahl = e.ids.length;
      await sende(
        empfaengerAusser(actor),
        "Bauakte",
        `${e.label} hat ${anzahl} weitere Änderungen gemacht — es gibt Updates.`,
        "bauakte-buendel",
      );
      await sb.from("aenderungen").update({ gesendet: true }).in("id", e.ids);
      versendet++;
    }
    return Response.json({ ok: true, buendel: versendet });
  }

  return Response.json({ ok: false, fehler: "unbekannter Modus" }, { status: 400 });
});
