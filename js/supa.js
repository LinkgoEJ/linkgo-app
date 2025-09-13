// js/supa.js (ESM)
// Stable API surface for LinkGo frontend against Supabase JS v2.
// Import via ESM (no bundler).
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.47.10/+esm';

/**
 * Read runtime config from window.CONFIG and fail fast if missing.
 */
const CFG = (() => {
  const c = (typeof window !== 'undefined' && window.CONFIG) ? window.CONFIG : null;
  if (!c || !c.SUPABASE_URL || !c.SUPABASE_ANON_KEY) {
    throw new Error(
      '[supa.js] Missing window.CONFIG.SUPABASE_URL / SUPABASE_ANON_KEY. ' +
      'Ensure /js/config.js sets window.CONFIG = { SUPABASE_URL, SUPABASE_ANON_KEY }.'
    );
  }
  return c;
})();

/**
 * Create a single Supabase client instance.
 */
const supabase = createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

/* ----------------------------- Internal helpers ---------------------------- */

/**
 * Normalize any Supabase-style promise into { data, error } and never throw.
 * If a Postgrest or Auth error appears, it will be mapped to { code, message }.
 * If an exception occurs, it is caught and returned as UNKNOWN.
 * @template T
 * @param {Promise<{ data: T | null, error: any }>} p
 * @returns {Promise<{ data: T | null, error: { code: string, message: string } | null }>}
 */
async function wrap(p) {
  try {
    const { data, error } = await p;
    if (error) {
      return {
        data: null,
        error: {
          code: error.code || 'UNKNOWN',
          message: error.message || String(error),
        },
      };
    }
    return { data: data ?? null, error: null };
  } catch (e) {
    return {
      data: null,
      error: { code: 'UNKNOWN', message: e?.message ? String(e.message) : String(e) },
    };
  }
}

/**
 * Fetch current authenticated user (or null if not logged in).
 * @returns {Promise<{ user: import('@supabase/supabase-js').User | null, error: {code:string, message:string} | null }>}
 */
async function getCurrentUser() {
  const { data, error } = await supabase.auth.getUser();
  if (error) {
    return { user: null, error: { code: error.code || 'AUTH_ERROR', message: error.message || 'Auth error' } };
  }
  return { user: data?.user ?? null, error: null };
}

/**
 * Require authentication for certain namespaces. If missing, return uniform error.
 * @returns {Promise<{ ok: boolean, userId: string | null, error: { code: string, message: string } | null }>}
 */
async function assertLoggedIn() {
  const { user, error } = await getCurrentUser();
  if (error) return { ok: false, userId: null, error };
  if (!user) return { ok: false, userId: null, error: { code: 'AUTH_REQUIRED', message: 'Login required' } };
  return { ok: true, userId: user.id, error: null };
}

/** @returns {string} ISO string for now (UTC) */
function nowISO() {
  return new Date().toISOString();
}

/* ---------------------------------- Auth ---------------------------------- */
export const Auth = {
  /**
   * Sign in using email/password.
   * @param {{ email: string, password: string }} params
   * @returns {Promise<{ data: { user: any, session: any } | null, error: { code: string, message: string } | null }>}
   * @example
   * const { data, error } = await Auth.signInWithPassword({ email, password });
   */
  async signInWithPassword({ email, password }) {
    return wrap(supabase.auth.signInWithPassword({ email, password }));
  },

  /**
   * Sign out current session.
   * @returns {Promise<{ data: { success: true } | null, error: { code: string, message: string } | null }>}
   */
  async signOut() {
    const res = await wrap(supabase.auth.signOut());
    if (res.error) return res;
    return { data: { success: true }, error: null };
  },

  /**
   * Get current session mapped to { user, access_token, expires_at }.
   * If no session, returns { data: null } (no error).
   * @returns {Promise<{ data: { user: any, access_token: string, expires_at: number } | null, error: { code: string, message: string } | null }>}
   */
  async getSession() {
    const { data, error } = await supabase.auth.getSession();
    if (error) {
      return { data: null, error: { code: error.code || 'AUTH_ERROR', message: error.message || 'Auth error' } };
    }
    const session = data?.session ?? null;
    if (!session) return { data: null, error: null };
    return {
      data: {
        user: session.user || null,
        access_token: session.access_token || null,
        expires_at: session.expires_at || null,
      },
      error: null,
    };
  },

  /**
   * Subscribe to auth state changes. Proxies Supabase listener.
   * Returns { data: { unsubscribe }, error:null }.
   * @param {(payload: { event: string, session: any }) => void} callback
   * @returns {Promise<{ data: { unsubscribe: () => void } | null, error: { code: string, message: string } | null }>}
   */
  async onAuthStateChange(callback) {
    try {
      const { data, error } = supabase.auth.onAuthStateChange((event, session) => {
        try {
          callback({ event, session });
        } catch (e) {
          // Swallow user callback errors to keep subscription stable
          console.error('[supa.js] onAuthStateChange callback error:', e);
        }
      });
      if (error) {
        return { data: null, error: { code: error.code || 'AUTH_ERROR', message: error.message || 'Auth error' } };
      }
      const unsubscribe = () => data.subscription.unsubscribe();
      return { data: { unsubscribe }, error: null };
    } catch (e) {
      return { data: null, error: { code: 'UNKNOWN', message: e?.message ? String(e.message) : String(e) } };
    }
  },
};

/* -------------------------------- Profiles -------------------------------- */
export const Profiles = {
  /**
   * Get the current user's profile from `profiles`.
   * Fields: id, role, full_name, region, bio, created_at
   * Requires login.
   * @returns {Promise<{ data: { id:string, role:string, full_name:string, region:string, bio:string, created_at:string } | null, error: { code:string, message:string } | null }>}
   */
  async getMyProfile() {
    const gate = await assertLoggedIn();
    if (!gate.ok) return { data: null, error: gate.error };

    return wrap(
      supabase
        .from('profiles')
        .select('id, role, full_name, region, bio, created_at')
        .eq('id', gate.userId)
        .maybeSingle()
    );
  },

  /**
   * Upsert the current user's profile in `profiles` by id = auth.user().id.
   * Only accepts: full_name, region, bio (role handled elsewhere).
   * Requires login.
   * @param {{ full_name?: string, region?: string, bio?: string }} payload
   * @returns {Promise<{ data: { id:string, role:string, full_name:string, region:string, bio:string, created_at:string } | null, error: { code:string, message:string } | null }>}
   */
  async upsertMyProfile({ full_name, region, bio }) {
    const gate = await assertLoggedIn();
    if (!gate.ok) return { data: null, error: gate.error };

    const row = {
      id: gate.userId,
      ...(full_name !== undefined ? { full_name } : {}),
      ...(region !== undefined ? { region } : {}),
      ...(bio !== undefined ? { bio } : {}),
    };

    return wrap(
      supabase
        .from('profiles')
        .upsert(row, { onConflict: 'id' })
        .select('id, role, full_name, region, bio, created_at')
        .maybeSingle()
    );
  },
};

/* -------------------------------- Catalog --------------------------------- */
export const Catalog = {
  /**
   * List talents from view `v_talent_catalog` with filters and pagination.
   * Projection: id, full_name, region, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate
   * Filters: q -> ilike(full_name, %q%), region -> eq(region, region)
   * Pagination: range(offset, offset+limit-1)
   * Sort: order('full_name', { ascending: true })
   * @param {{ q?: string|null, region?: string|null, limit?: number, offset?: number }} [params]
   * @returns {Promise<{ data: Array<{
   *   id:string, full_name:string, region:string, is_referee:boolean, is_coach:boolean,
   *   experience_years:number|null, primary_levels:string[]|null, travel_km:number|null, hourly_rate:number|null
   * }> | null, error: { code:string, message:string } | null }>}
   */
  async list({ q = null, region = null, limit = 20, offset = 0 } = {}) {
    let query = supabase
      .from('v_talent_catalog')
      .select(
        'id, full_name, region, is_referee, is_coach, experience_years, primary_levels, travel_km, hourly_rate'
      )
      .order('full_name', { ascending: true })
      .range(offset, Math.max(offset, offset + (limit ?? 20) - 1));

    if (q && String(q).trim().length > 0) {
      query = query.ilike('full_name', `%${q}%`);
    }
    if (region && String(region).trim().length > 0) {
      query = query.eq('region', region);
    }

    return wrap(query);
  },
};

/* -------------------------------- Bookings -------------------------------- */
export const Bookings = {
  /**
   * Create a booking request.
   * Inserts into `bookings` with status = 'requested'.
   * Server-side constraints may reject overlaps or invalid status transitions.
   * Requires login.
   * @param {{
   *   talent_id: string,
   *   role_at_booking: 'referee' | 'coach',
   *   start_ts: string, // ISO timestamp
   *   end_ts: string,   // ISO timestamp
   *   location?: string|null,
   *   message?: string|null
   * }} payload
   * @returns {Promise<{ data: { id:string } | null, error: { code:string, message:string } | null }>}
   * Possible errors: AUTH_REQUIRED, RLS/policy denied, time conflict constraints.
   */
  async request({ talent_id, role_at_booking, start_ts, end_ts, location = null, message = null }) {
    const gate = await assertLoggedIn();
    if (!gate.ok) return { data: null, error: gate.error };

    const insertRow = {
      manager_id: gate.userId,
      talent_id,
      role_at_booking,
      status: 'requested',
      start_ts,
      end_ts,
      location,
      message,
      created_at: nowISO(),
    };

    // Expect server-side constraints (no-overlap, status machine) to enforce business rules.
    const res = await wrap(
      supabase
        .from('bookings')
        .insert(insertRow)
        .select('id')
        .maybeSingle()
    );

    // If constraint fails, return a clearer message for common cases.
    if (res.error && /overlap|conflict|time/i.test(res.error.message)) {
      res.error.message = 'time conflict';
    }
    return res;
  },

  /**
   * Respond to a booking (accept/decline/cancel).
   * Updates `status` accordingly and sets `responded_at = now()` when relevant.
   * Actual allowed transitions are enforced by DB constraints/RLS.
   * Requires login.
   * @param {{ booking_id: string, action: 'accept'|'decline'|'cancel' }} params
   * @returns {Promise<{ data: { id:string, status:string } | null, error: { code:string, message:string } | null }>}
   */
  async respond({ booking_id, action }) {
    const gate = await assertLoggedIn();
    if (!gate.ok) return { data: null, error: gate.error };

    const actionToStatus = {
      accept: 'accepted',
      decline: 'declined',
      cancel: 'cancelled',
    };
    const nextStatus = actionToStatus[action];
    if (!nextStatus) {
      return { data: null, error: { code: 'BAD_REQUEST', message: 'Invalid action' } };
    }

    const updateRow = {
      status: nextStatus,
      responded_at: nowISO(),
      // updated_at could be handled by DB trigger; include if not present server-side.
      updated_at: nowISO(),
    };

    const res = await wrap(
      supabase
        .from('bookings')
        .update(updateRow)
        .eq('id', booking_id)
        .select('id, status')
        .maybeSingle()
    );

    if (res.error && /transition|not allowed|invalid/i.test(res.error.message)) {
      res.error.message = 'invalid status transition';
    }
    return res;
  },

  /**
   * List my bookings (as manager or as talent) with optional filters and pagination.
   * Requires login.
   * @param {{
   *   role?: 'manager'|'talent',
   *   status?: string|null,
   *   from?: string|null, // ISO lower bound on start_ts
   *   to?: string|null,   // ISO upper bound on end_ts
   *   limit?: number,
   *   offset?: number
   * }} [params]
   * @returns {Promise<{ data: Array<{
   *   id:string, manager_id:string, talent_id:string, role_at_booking:string, status:string,
   *   start_ts:string, end_ts:string, location:string|null, message:string|null, created_at:string
   * }>|null, error: { code:string, message:string } | null }>}
   */
  async listMine({ role = 'manager', status = null, from = null, to = null, limit = 20, offset = 0 } = {}) {
    const gate = await assertLoggedIn();
    if (!gate.ok) return { data: null, error: gate.error };

    let query = supabase
      .from('bookings')
      .select('id, manager_id, talent_id, role_at_booking, status, start_ts, end_ts, location, message, created_at')
      .order('start_ts', { ascending: true })
      .range(offset, Math.max(offset, offset + (limit ?? 20) - 1));

    if (role === 'manager') {
      query = query.eq('manager_id', gate.userId);
    } else if (role === 'talent') {
      query = query.eq('talent_id', gate.userId);
    } else {
      return { data: null, error: { code: 'BAD_REQUEST', message: 'Invalid role' } };
    }

    if (status && String(status).trim().length > 0) {
      query = query.eq('status', status);
    }
    if (from && String(from).trim().length > 0) {
      query = query.gte('start_ts', from);
    }
    if (to && String(to).trim().length > 0) {
      query = query.lte('end_ts', to);
    }

    return wrap(query);
  },

  /**
   * Get a single booking by id.
   * Requires login.
   * @param {{ booking_id: string }} params
   * @returns {Promise<{ data: {
   *   id:string, manager_id:string, talent_id:string, role_at_booking:string, status:string,
   *   start_ts:string, end_ts:string, location:string|null, message:string|null, created_at:string
   * } | null, error: { code:string, message:string } | null }>}
   */
  async get({ booking_id }) {
    const gate = await assertLoggedIn();
    if (!gate.ok) return { data: null, error: gate.error };

    return wrap(
      supabase
        .from('bookings')
        .select('id, manager_id, talent_id, role_at_booking, status, start_ts, end_ts, location, message, created_at')
        .eq('id', booking_id)
        .maybeSingle()
    );
  },
};

/* ------------------------------- Default export ---------------------------- */
const api = { Auth, Profiles, Catalog, Bookings };
export default api;

/* --------------------------------- Smoke notes ------------------------------
Acceptance tests (manual; run in console with a seeded dev DB):

// Auth
// 1) const { data: s1 } = await Auth.signInWithPassword({ email:'known@user.test', password:'secret' });
// 2) const { data: ses } = await Auth.getSession(); // should include user

// Profiles
// await Profiles.upsertMyProfile({ full_name:'Test', region:'Stockholm', bio:'Hello' });
// const { data: me } = await Profiles.getMyProfile(); // full_name === 'Test', region === 'Stockholm'

// Catalog
// const { data: list } = await Catalog.list({ limit:5 }); // expect >= 1 row, no error

// Bookings
// const start = new Date(Date.now() + 7*24*3600*1000).toISOString(); // +7d
// const end   = new Date(Date.now() + 7*24*3600*1000 + 60*60*1000).toISOString(); // +1h
// const { data: req } = await Bookings.request({ talent_id:'<some-talent-id>', role_at_booking:'referee', start_ts:start, end_ts:end, location:'Pitch 1', message:'Friendly' });
// const { data: upd } = await Bookings.respond({ booking_id: req.id, action:'decline' });
// const { data: mine } = await Bookings.listMine({ role:'manager' });

------------------------------------------------------------------------------- */
