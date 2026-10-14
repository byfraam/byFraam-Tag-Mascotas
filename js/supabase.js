(function () {
  "use strict";
  const c = window.BF_CONFIG;
  if (!c || !c.SUPABASE_URL || !c.SUPABASE_PUBLISHABLE_KEY ||
      c.SUPABASE_URL.includes("PEGAR_") || c.SUPABASE_PUBLISHABLE_KEY.includes("PEGAR_")) {
    console.error("Configurá js/config.js con la URL y la publishable key de Supabase.");
    return;
  }
  if (!window.supabase || !window.supabase.createClient) {
    console.error("No se pudo cargar la biblioteca de Supabase.");
    return;
  }
  window.BF = window.supabase.createClient(c.SUPABASE_URL, c.SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
})();
