
(function () {
  "use strict";

  const config = window.BF_SUPABASE_CONFIG;

  if (!config) {
    console.error(
      "by Fraam: no se encontró la configuración de Supabase."
    );
    return;
  }

  if (
    !config.SUPABASE_URL ||
    !config.SUPABASE_PUBLISHABLE_KEY ||
    config.SUPABASE_URL.includes("PEGAR_AQUI") ||
    config.SUPABASE_PUBLISHABLE_KEY.includes("PEGAR_AQUI")
  ) {
    console.error(
      "by Fraam: revisá la URL y la clave pública de Supabase en js/config.js."
    );
    return;
  }

  if (!window.supabase || !window.supabase.createClient) {
    console.error(
      "by Fraam: no se cargó la biblioteca de Supabase."
    );
    return;
  }

  window.BF_SUPABASE = window.supabase.createClient(
    config.SUPABASE_URL,
    config.SUPABASE_PUBLISHABLE_KEY
  );

  console.info("by Fraam: cliente de Supabase inicializado.");
})();
