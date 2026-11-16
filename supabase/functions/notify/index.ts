// Mimo · función "notify" (Supabase Edge Function)
// Se ejecuta cada 15 minutos (ver cron.sql) y manda notificaciones push:
//   - 1 hora antes de que acabe el plazo de una misión con horario.
//   - A la hora elegida por cada jugador (22:00 por defecto), un resumen de lo pendiente.
// Cada aviso se envía como mucho una vez al día (tabla notification_log).
//
// Secretos necesarios (Edge Functions → Secrets):
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, CRON_SECRET
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los pone Supabase automáticamente.

import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

// ==== LÓGICA (sin dependencias; la misma que la app) ====
const DAY_START = 3;             // el día de Mimo termina a las 3:00
const QUIET_FROM = 0, QUIET_TO = 7; // sin avisos entre las 0:00 y las 7:00
const GLASSES_GOAL = 8;
const HABITS = [
  { id: 'am',      kind: 'brush',  to: 12, text: 'lavarte los dientes de la mañana', short: 'dientes de la mañana' },
  { id: 'md',      kind: 'brush',  to: 17, text: 'lavarte los dientes del mediodía', short: 'dientes del mediodía' },
  { id: 'pm',      kind: 'brush',  to: 27, text: 'lavarte los dientes de la noche',  short: 'dientes de la noche' },
  { id: 'water',   kind: 'water',  short: 'beber agua' },
  { id: 'steps',   kind: 'steps',  short: 'caminar' },
  { id: 'read',    kind: 'check',  short: 'leer 20 min' },
  { id: 'bed',     kind: 'check',  short: 'hacer la cama' },
  { id: 'kitchen', kind: 'check',  short: 'ordenar la cocina' },
  { id: 'bath',    kind: 'weekly', short: 'fregar el baño' }
];
const H = Object.fromEntries(HABITS.map(h => [h.id, h]));
const DEFAULT_ON = { brush: true, water: true, steps: true, read: true, bed: true, kitchen: true, bath: true };
const DEFAULT_NOTIFY = { on: false, deadline: true, hour: 22 };

const pad = n => String(n).padStart(2, '0');
const fmtH = h => pad(h % 24) + ':00';
const keyUTC = dt => dt.getUTCFullYear() + '-' + pad(dt.getUTCMonth() + 1) + '-' + pad(dt.getUTCDate());
const fmtNum = n => Number(n || 0).toLocaleString('es-ES');

function activeIds(settings) {
  const on = Object.assign({}, DEFAULT_ON, (settings && settings.on) || {});
  return HABITS.filter(h => on[h.kind === 'brush' ? 'brush' : h.id] !== false).map(h => h.id);
}

// Hora local del jugador y su "día de Mimo" (de 3:00 a 3:00)
function localClock(now, tz) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-GB', {
    timeZone: tz, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
  }).formatToParts(now).map(p => [p.type, p.value]));
  const wall = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute);
  const logical = new Date(wall - DAY_START * 3600e3);
  let hour = +parts.hour + +parts.minute / 60;
  const clockHour = hour;
  if (hour < DAY_START) hour += 24;
  const monday = new Date(logical.getTime() - ((logical.getUTCDay() + 6) % 7) * 86400e3);
  return { day: keyUTC(logical), weekStart: keyUTC(monday), hour, clockHour };
}

function isDone(id, r) {
  const h = H[id];
  if (h.kind === 'water') return (r.glasses || []).length >= GLASSES_GOAL;
  if (h.kind === 'steps') return (r.steps || 0) >= (r.sg || 8000);
  return !!r[id];
}

// Decide qué avisos tocan ahora para un jugador.
// rows: sus day_logs de esta semana ({day, am, md, pm, glasses, extra})
function decide(now, settings, rows) {
  settings = settings || {};
  const notify = Object.assign({}, DEFAULT_NOTIFY, settings.notify || {});
  if (!notify.on) return [];
  const clk = localClock(now, settings.tz || 'Europe/Madrid');
  if (clk.clockHour >= QUIET_FROM && clk.clockHour < QUIET_TO) return [];
  const byDay = {};
  for (const r of rows || []) byDay[r.day] = Object.assign({ am: r.am, md: r.md, pm: r.pm, glasses: r.glasses || [] }, r.extra || {});
  const today = byDay[clk.day] || { glasses: [], sg: settings.stepGoal };
  if (!today.sg) today.sg = settings.stepGoal || 8000;
  const ids = today.h || activeIds(settings);
  const out = [];

  if (notify.deadline) {
    for (const id of ids) {
      const h = H[id];
      if (!h || h.to === undefined || isDone(id, today)) continue;
      if (clk.hour >= h.to - 1 && clk.hour < h.to) {
        out.push({ kind: 'deadline-' + id, day: clk.day, title: '⏰ Te queda 1 hora',
                   body: `Recuerda ${h.text} antes de las ${fmtH(h.to)}. Mimo cuenta contigo.` });
      }
    }
  }

  const hour = Number(notify.hour);
  if (hour >= 0 && clk.hour >= hour && clk.hour < hour + 2) {
    const pending = [];
    for (const id of ids) {
      const h = H[id];
      if (!h) continue;
      if (h.kind === 'weekly') {
        const doneWeek = Object.keys(byDay).some(k => k >= clk.weekStart && k <= clk.day && byDay[k][id]);
        if (!doneWeek) pending.push(h.short + ' (esta semana)');
        continue;
      }
      if (h.to !== undefined && clk.hour >= h.to) continue; // plazo ya pasado: no tiene arreglo
      if (isDone(id, today)) continue;
      if (h.kind === 'water') pending.push(`${h.short} (${(today.glasses || []).length}/${GLASSES_GOAL} vasos)`);
      else if (h.kind === 'steps') pending.push(`${h.short} (${fmtNum(today.steps || 0)} de ${fmtNum(today.sg)} pasos)`);
      else pending.push(h.short);
    }
    if (pending.length) {
      out.push({ kind: 'daily', day: clk.day, title: '🌙 Mimo te espera',
                 body: 'Aún te falta: ' + pending.join(', ') + '.' });
    }
  }
  return out;
}
// ==== FIN LÓGICA ====

Deno.serve(async (req) => {
  if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) {
    return new Response('forbidden', { status: 403 });
  }
  webpush.setVapidDetails('https://ericveganoguera.github.io/mimo/',
    Deno.env.get('VAPID_PUBLIC_KEY'), Deno.env.get('VAPID_PRIVATE_KEY'));
  const sb = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));

  const { data: subs, error } = await sb.from('push_subscriptions').select('endpoint,p256dh,auth,user_id');
  if (error) return new Response(error.message, { status: 500 });
  const users = [...new Set((subs || []).map(s => s.user_id))];
  if (!users.length) return Response.json({ users: 0, sent: 0 });

  const { data: profiles } = await sb.from('profiles').select('id,settings').in('id', users);
  const now = new Date();
  let sent = 0, removed = 0;

  for (const p of profiles || []) {
    const settings = p.settings || {};
    const clk = localClock(now, settings.tz || 'Europe/Madrid');
    const { data: rows } = await sb.from('day_logs')
      .select('day,am,md,pm,glasses,extra')
      .eq('user_id', p.id).gte('day', clk.weekStart).lte('day', clk.day);
    const messages = decide(now, settings, rows);
    for (const m of messages) {
      // Registrar primero: si ya existía, este aviso ya se mandó hoy
      const { error: dup } = await sb.from('notification_log').insert({ user_id: p.id, day: m.day, kind: m.kind });
      if (dup) continue;
      for (const s of (subs || []).filter(x => x.user_id === p.id)) {
        try {
          await webpush.sendNotification(
            { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
            JSON.stringify({ title: m.title, body: m.body, tag: m.kind }),
            { TTL: 3600 });
          sent++;
        } catch (e) {
          if (e && (e.statusCode === 404 || e.statusCode === 410)) {
            await sb.from('push_subscriptions').delete().eq('endpoint', s.endpoint);
            removed++;
          } else console.error('push', e && e.statusCode, e && e.body);
        }
      }
    }
  }
  return Response.json({ users: users.length, sent, removed });
});
