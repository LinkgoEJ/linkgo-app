/**
 * Global config for building absolute URLs consistently.
 * SITE_URL defaults to window.location.origin at runtime.
 */
window.CONFIG = {
  SITE_URL: window.CONFIG?.SITE_URL || 'http://localhost:5500',
  DEBUG: true,
  ...window.CONFIG
};
