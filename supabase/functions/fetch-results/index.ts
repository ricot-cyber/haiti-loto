// Rezilta otomatik. Deploy: Edge Functions > Deploy a new function > "fetch-results"
// Pwograme li: Integrations > Cron > chak 10 minit > Supabase Edge Function > fetch-results
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const digits = (v: unknown, n: number) => {
  const s = String(v ?? '').replace(/\D/g, '');
  return s.length === n ? s : null;
};

Deno.serve(async () => {
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const log: Record<string, string> = {};

  async function save(code: string, date: string, p3: string | null, p4: string | null) {
    if (!p3 || !p4) { log[`${code} ${date}`] = 'poko disponib'; return; }
    const { error } = await sb.rpc('apply_picks', { p_draw_code: code, p_date: date, p_pick3: p3, p_pick4: p4 });
    log[`${code} ${date}`] = error ? `erè: ${error.message}` : `OK ${p3} ${p4}`;
  }

  // ---- NEW YORK: done ofisyèl gratis (NY Open Data, dataset hsys-3def)
  try {
    const r = await fetch('https://data.ny.gov/resource/hsys-3def.json?$order=draw_date%20DESC&$limit=3');
    const rows = await r.json();
    for (const row of rows) {
      const date = String(row.draw_date).slice(0, 10);
      await save('NY_MATIN', date, digits(row.midday_daily, 3), digits(row.midday_win_4, 4));
      await save('NY_ASWE', date, digits(row.evening_daily, 3), digits(row.evening_win_4, 4));
    }
  } catch (e) { log['NY'] = `erè: ${(e as Error).message}`; }

  // ---- GEORGIA / FLORIDA: pa gen API ofisyèl gratis.
  // Ajoute yon sous isit la (egzanp yon API peye) epi rele save('GA_MATIN', date, pick3, pick4) ...
  log['GA/FL'] = 'pa konfigire (antre rezilta yo pa men nan app la, tab Rezilta)';

  return new Response(JSON.stringify(log, null, 2), { headers: { 'Content-Type': 'application/json' } });
});
