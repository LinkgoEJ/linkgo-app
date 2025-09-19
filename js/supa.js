// js/supa.js
// Antag ESM i browser. Se till att @supabase/supabase-js är inkluderad i projektet via CDN eller bundlat.
// Om ni kör CDN, lägg <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script> i <head> på sidorna.
// Om ni redan har klienten – behåll men ersätt init-delen med denna defensiva.

const cfg = (window.CONFIG || {});
const SB_URL = cfg.SUPABASE_URL;
const SB_ANON = cfg.SUPABASE_ANON_KEY;

if (!SB_URL || !SB_ANON) {
  console.error('[AuthBoot] Missing SUPABASE_URL or SUPABASE_ANON_KEY in window.CONFIG', window.CONFIG);
  throw new Error('Supabase config saknas. Fyll i SUPABASE_URL och SUPABASE_ANON_KEY i public/config.js');
}

// globalThis.supabase kan redan finnas om ni initierat via CDN. Skapa om inte.
let supabaseClient = globalThis.supabase?.createClient
  ? globalThis.supabase.createClient(SB_URL, SB_ANON)
  : (typeof createClient === 'function'
      ? createClient(SB_URL, SB_ANON) // om createClient ligger globalt
      : null);

if (!supabaseClient) {
  console.error('[AuthBoot] Supabase client kunde inte skapas. Har du laddat in supabase-js?');
  throw new Error('Saknar Supabase-klient. Lägg in supabase-js via CDN eller bundling.');
}

async function healthCheck() {
  try {
    const { data, error } = await supabaseClient.auth.getSession();
    if (error) throw error;
    return { ok: true, session: data.session || null };
  } catch (e) {
    return { ok: false, error: String(e && e.message || e) };
  }
}

const Auth = {
  async getSession() {
    const { data, error } = await supabaseClient.auth.getSession();
    if (error) throw error;
    return { session: data.session, user: data.session?.user || null };
  },
  async signInWithPassword({ email, password }) {
    const { data, error } = await supabaseClient.auth.signInWithPassword({ email, password });
    return { session: data?.session || null, user: data?.user || null, error };
  },
  async signUpWithEmail({ email, password, data }) {
    const { data: res, error } = await supabaseClient.auth.signUp({
      email, password, options: { data }
    });
    const session = res?.session || null;
    const user = res?.user || null;
    const needsConfirmation = !session && !error && !!user;
    return { user, session, error, needsConfirmation };
  },
  async signOut() {
    const { error } = await supabaseClient.auth.signOut();
    if (error) throw error;
  },
  async requireSession() {
    const { session } = await this.getSession();
    if (!session) location.href = './login.html';
  },
  redirectToHome() { location.href = './home.html'; },
  healthCheck,
};

const Profiles = {
  async getMyProfile() {
    const { data: sessionData } = await supabaseClient.auth.getSession();
    const uid = sessionData?.session?.user?.id;
    if (!uid) return null;
    const { data, error } = await supabaseClient.from('profiles').select('*').eq('id', uid).single();
    if (error) throw error;
    return data;
  }
};

const supa = { Auth, Profiles };
export default supa;
