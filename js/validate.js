// public/validate.js
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm'

const $ = (id) => document.getElementById(id)
const set = (el, txt) => { if (el) el.textContent = typeof txt === 'string' ? txt : JSON.stringify(txt, null, 2) }
const dump = (o) => o?.error ? `ERROR: ${o.error.message}\n` + JSON.stringify(o, null, 2) : JSON.stringify(o, null, 2)

function assertConfig(){
  const cfg = window.CONFIG || {}
  const ok = !!(cfg.SUPABASE_URL && cfg.SUPABASE_ANON_KEY)
  set($('env'), ok ? 'ENV OK' : 'ENV MISSING')
  if (!ok) throw new Error('Missing window.CONFIG (SUPABASE_URL / SUPABASE_ANON_KEY)')
  return cfg
}

function client(){
  const { SUPABASE_URL, SUPABASE_ANON_KEY } = assertConfig()
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth:{ persistSession:false, autoRefreshToken:false }})
}

async function runCatalog(){
  set($('out-catalog'), 'Running…')
  try{
    const sb = client()
    const { data, error } = await sb
      .from('v_talent_catalog')
      .select('id,full_name,region,is_referee,is_coach')
      .limit(5)
    if (error) return set($('out-catalog'), dump({ error }))
    const rows = (data||[]).map(r=> `${r.full_name} — ${r.region} — ${r.is_referee?'ref':''}${r.is_coach?'coach':''}`)
    set($('out-catalog'), `Rows: ${data?.length||0}\n` + rows.join('\n'))
    console.log('[catalog] ok', data?.length||0)
  }catch(e){
    set($('out-catalog'), String(e?.message||e))
    console.error(e)
  }
}

async function runRls(){
  set($('out-rls'), 'Running…')
  try{
    const sb = client()
    const { data, error, status } = await sb.from('profiles').select('*').limit(1)
    if (error) return set($('out-rls'), `PASS (RLS blocked)\nstatus=${status}\nmessage=${error.message}`)
    set($('out-rls'), `FAIL (RLS did not block)\n${dump({ data })}`)
    console.warn('[rls] open?', data)
  }catch(e){
    set($('out-rls'), String(e?.message||e))
    console.error(e)
  }
}

document.addEventListener('DOMContentLoaded', ()=>{
  try { assertConfig() } catch(e){ console.error(e) }
  $('btn-catalog')?.addEventListener('click', runCatalog)
  $('btn-rls')?.addEventListener('click', runRls)
  console.log('[validate] wired')
})
