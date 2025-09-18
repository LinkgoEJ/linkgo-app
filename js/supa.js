// js/supa.js (ESM)
// Stable API surface for LinkGo frontend against Supabase JS v2.
// Import via ESM (no bundler).
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.47.10/+esm';

// --- Config ---
const CFG = {
  SUPABASE_URL: 'https://wupbylrjorizbudxfktl.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1cGJ5bHJqb3JpemJ1ZHhma3RsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcyNjExMDksImV4cCI6MjA3MjgzNzEwOX0.tQAfScNXAC0s4N8Qf8gFpWtO5lFLHiPzE57Qf8kvzJc'
};

// --- Client ---
const supabase = createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY);

// --- Helpers ---
const getCurrentUser = () => {
  const { data: { user } } = supabase.auth.getUser();
  return user;
};

const assertLoggedIn = () => {
  const user = getCurrentUser();
  if (!user) throw new Error('Not authenticated');
  return user;
};

// --- Auth Module ---
export const Auth = {
  async getSession() {
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;
    return { session: data.session, user: data.session?.user || null };
  },

  async signInWithPassword({ email, password }) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    return { session: data?.session || null, user: data?.user || null, error };
  },

  async signUpWithEmail({ email, password, data }) {
    const { data:res, error } = await supabase.auth.signUp({ email, password, options: { data } });
    const session = res?.session || null;
    const user = res?.user || null;
    const needsConfirmation = !session && !error && !!user; // klassiskt Supabase-flöde
    return { user, session, error, needsConfirmation };
  },

  async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  },

  redirectToHome() { 
    location.href = './home.html'; 
  }
};

// --- Profiles Module ---
export const Profiles = {
  async getMyProfile() {
    const { data: sessionData } = await supabase.auth.getSession();
    const uid = sessionData?.session?.user?.id;
    if (!uid) return null;
    const { data, error } = await supabase.from('profiles').select('*').eq('id', uid).single();
    if (error) throw error;
    return data;
  }
};

// --- Default Export ---
export default { Auth, Profiles };