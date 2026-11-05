// Deploy: supabase functions deploy create-vendor
// Kle service_role rete sou sèvè a (SUPABASE_SERVICE_ROLE_KEY ajoute otomatikman).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const jwt = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    const { data: { user } } = await admin.auth.getUser(jwt);
    if (!user) throw new Error('Pa otorize');

    const { data: me } = await admin.from('profiles').select('role,active').eq('id', user.id).single();
    if (me?.role !== 'director' || !me.active) throw new Error('Se direktè sèlman ki ka kreye vandè');

    const { username, password, full_name, commission_pct } = await req.json();
    if (!/^[a-z0-9_.-]{3,30}$/i.test(username ?? '')) throw new Error('Username pa valid (3-30 karaktè, lèt/chif)');
    if ((password ?? '').length < 6) throw new Error('Password dwe gen 6 karaktè omwen');

    const uname = username.toLowerCase();
    const { data, error } = await admin.auth.admin.createUser({
      email: `${uname}@haitiloto.app`,
      password,
      email_confirm: true,
    });
    if (error) throw error;

    const { error: e2 } = await admin.from('profiles').insert({
      id: data.user.id, role: 'vendor', username: uname,
      full_name, director_id: user.id, commission_pct: commission_pct ?? 10,
    });
    if (e2) { await admin.auth.admin.deleteUser(data.user.id); throw e2; }
    return json({ ok: true, id: data.user.id });
  } catch (e) {
    return json({ error: (e as Error).message }, 400);
  }
});
