// public/config.js
window.CONFIG = {
  // ⚠️ FYLL I DINA RIKTIGA PRODVÄRDEN ELLER DEV-VÄRDEN
  SUPABASE_URL: window.CONFIG?.SUPABASE_URL || 'https://wupbylrjorizbudxfktl.supabase.co',
  SUPABASE_ANON_KEY: window.CONFIG?.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1cGJ5bHJqb3JpemJ1ZHhma3RsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcyNjExMDksImV4cCI6MjA3MjgzNzEwOX0.tQAfScNXAC0s4N8Qf8gFpWtO5lFLHiPzE57Qf8kvzJc',

  SITE_URL: window.CONFIG?.SITE_URL || (location.origin || 'http://localhost:5500'),
  DEBUG: true,
  ...window.CONFIG,
};
