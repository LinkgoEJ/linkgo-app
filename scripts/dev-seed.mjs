// scripts/dev-seed.mjs
// WARNING: Dev seed only. Do not run in production.

import dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

import { createClient } from '@supabase/supabase-js';

// --- Guards for env + production ---
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE, NODE_ENV } = process.env;
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
  throw new Error(
    '[dev-seed] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE in .env.local'
  );
}
if ((NODE_ENV || '').toLowerCase() === 'production') {
  throw new Error('[dev-seed] Refusing to run in production (NODE_ENV=production)');
}

// --- Supabase admin client ---
const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// --- Helpers ---
async function ensureUser({ email, password, full_name, role, region, bio }) {
  // 1) Try to create auth user (confirmed)
  let userId = null;
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name },
  });

  if (createErr) {
    // If already exists, fetch user id by email
    const msg = (createErr.message || '').toLowerCase();
    // Common Supabase message fragment: "User already registered"
    if (msg.includes('already') && msg.includes('register')) {
      const { data: listed, error: listErr } = await admin.auth.admin.listUsers({ email });
      if (listErr) {
        throw new Error(`[dev-seed] listUsers failed for ${email}: ${listErr.message}`);
      }
      const found =
        listed?.users?.find(
          (u) => (u.email || '').toLowerCase() === email.toLowerCase()
        ) || null;
      if (!found) {
        throw new Error(
          `[dev-seed] user exists in auth but not returned by listUsers(): ${email}`
        );
      }
      userId = found.id;
    } else {
      throw new Error(`[dev-seed] createUser failed for ${email}: ${createErr.message}`);
    }
  } else {
    userId = created?.user?.id;
  }

  if (!userId) {
    throw new Error(`[dev-seed] No user id for ${email}`);
  }

  // 2) Upsert profile row
  const profileRow = {
    id: userId,
    role,
    full_name,
    region,
    bio: bio ?? null,
  };

  const { error: upsertErr } = await admin
    .from('profiles')
    .upsert(profileRow, { onConflict: 'id' });

  if (upsertErr) {
    // Allow duplicate key issues to pass
    const m = (upsertErr.message || '').toLowerCase();
    if (m.includes('duplicate key')) {
      console.warn(`[dev-seed] profiles upsert duplicate for ${email}, continuing…`);
    } else {
      throw new Error(`[dev-seed] profiles upsert failed for ${email}: ${upsertErr.message}`);
    }
  }

  return { id: userId, email };
}

async function upsertTalentDetails(talentId, details) {
  const row = { talent_id: talentId, ...details };
  const { error } = await admin
    .from('talent_details')
    .upsert(row, { onConflict: 'talent_id' });
  if (error) {
    const m = (error.message || '').toLowerCase();
    if (m.includes('duplicate key')) {
      console.warn('[dev-seed] talent_details duplicate, continuing…');
    } else {
      throw new Error(`[dev-seed] upsertTalentDetails failed: ${error.message}`);
    }
  }
}

async function addAvail(talentId, weekday, start, end, notes = '') {
  const row = {
    talent_id: talentId,
    weekday,
    start_time: start, // 'HH:MM'
    end_time: end, // 'HH:MM'
    notes,
  };
  const { error } = await admin.from('availability').insert(row).single();
  if (error) {
    const m = (error.message || '').toLowerCase();
    if (m.includes('duplicate')) {
      console.warn('[dev-seed] availability duplicate, continuing…');
    } else {
      throw new Error(`[dev-seed] addAvail failed: ${error.message}`);
    }
  }
}

async function insertOne(table, row) {
  const { data, error } = await admin.from(table).insert(row).single();
  if (error) {
    const m = (error.message || '').toLowerCase();
    if (m.includes('duplicate')) {
      console.warn(`[dev-seed] ${table} duplicate, continuing…`);
      return null;
    }
    throw new Error(`[dev-seed] insert into ${table} failed: ${error.message}`);
  }
  return data;
}

// Small date helper for local time → ISO
function localISOPlusDays(days, hh, mm) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(hh, mm, 0, 0);
  return d.toISOString(); // ISO UTC; fine for timestamptz
}

(async () => {
  try {
    console.log('--- LinkGo Dev Seed ---');

    const PASSWORD = 'LinkGo123!';

    // Managers
    const managerAlfa = await ensureUser({
      email: 'manager.alfa@example.com',
      password: PASSWORD,
      full_name: 'Manager Alfa',
      role: 'manager',
      region: 'Stockholm',
      bio: 'Seed manager',
    });

    const managerBeta = await ensureUser({
      email: 'manager.beta@example.com',
      password: PASSWORD,
      full_name: 'Manager Beta',
      role: 'manager',
      region: 'Stockholm',
      bio: 'Seed manager',
    });

    // Talents
    const ref1 = await ensureUser({
      email: 'ref1@example.com',
      password: PASSWORD,
      full_name: 'Domare 1',
      role: 'talent',
      region: 'Stockholm',
      bio: 'Seed talent',
    });
    await upsertTalentDetails(ref1.id, {
      is_referee: true,
      is_coach: false,
      experience_years: 2,
      primary_levels: ['U11', 'U13'],
      travel_km: 15,
      hourly_rate: null,
    });

    const ref2 = await ensureUser({
      email: 'ref2@example.com',
      password: PASSWORD,
      full_name: 'Domare 2',
      role: 'talent',
      region: 'Stockholm',
      bio: 'Seed talent',
    });
    await upsertTalentDetails(ref2.id, {
      is_referee: true,
      is_coach: false,
      experience_years: 4,
      primary_levels: ['U9', 'U11', 'U13'],
      travel_km: 10,
      hourly_rate: null,
    });

    const coach1 = await ensureUser({
      email: 'coach1@example.com',
      password: PASSWORD,
      full_name: 'Tränare 1',
      role: 'talent',
      region: 'Stockholm',
      bio: 'Seed coach',
    });
    await upsertTalentDetails(coach1.id, {
      is_referee: false,
      is_coach: true,
      experience_years: 3,
      primary_levels: ['U11', 'U13'],
      travel_km: 20,
      hourly_rate: 200,
    });

    // Availability for all talents: Mon/Wed/Fri (1,3,5), 18:00–20:00
    const weekdays = [1, 3, 5];
    for (const w of weekdays) {
      await addAvail(ref1.id, w, '18:00', '20:00', 'Seed slot');
      await addAvail(ref2.id, w, '18:00', '20:00', 'Seed slot');
      await addAvail(coach1.id, w, '18:00', '20:00', 'Seed slot');
    }

    // Team for Manager Alfa
    await insertOne('teams', {
      manager_id: managerAlfa.id,
      club_name: 'LinkGo IF',
      team_name: 'U13',
      age_group: 'U13',
      level: 'Medel',
      region: 'Stockholm',
    });

    // Bookings (status requested)
    // 1) Manager Alfa → Ref1: tomorrow 18:00–19:30
    const b1Start = localISOPlusDays(1, 18, 0);
    const b1End = localISOPlusDays(1, 19, 30);
    const b1 = await insertOne('bookings', {
      manager_id: managerAlfa.id,
      talent_id: ref1.id,
      role_at_booking: 'referee',
      start_ts: b1Start,
      end_ts: b1End,
      location: 'Skytteholms IP',
      message: 'Träningsmatch U13',
      status: 'requested',
    });

    // 2) Manager Beta → Coach1: day after tomorrow 17:00–18:30
    const b2Start = localISOPlusDays(2, 17, 0);
    const b2End = localISOPlusDays(2, 18, 30);
    const b2 = await insertOne('bookings', {
      manager_id: managerBeta.id,
      talent_id: coach1.id,
      role_at_booking: 'coach',
      start_ts: b2Start,
      end_ts: b2End,
      location: 'Zinkensdamms IP',
      message: 'Teknikpass',
      status: 'requested',
    });

    // Output summary table
    const rows = [
      { email: managerAlfa.email, id: managerAlfa.id, role: 'manager' },
      { email: managerBeta.email, id: managerBeta.id, role: 'manager' },
      { email: ref1.email, id: ref1.id, role: 'talent' },
      { email: ref2.email, id: ref2.id, role: 'talent' },
      { email: coach1.email, id: coach1.id, role: 'talent' },
    ];
    console.table(rows);

    console.log('Created booking IDs:', {
      booking1: b1?.id || '(existing/duplicate)',
      booking2: b2?.id || '(existing/duplicate)',
    });

    console.log('--- Dev seed done ---');
    process.exit(0);
  } catch (err) {
    console.error('[dev-seed] FAILED:', err?.message || err);
    process.exit(1);
  }
})();
