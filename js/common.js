window.BFCommon = {
  el(id) { return document.getElementById(id); },
  msg(id, text, type) {
    const e = document.getElementById(id); if (!e) return;
    e.textContent = text || ''; e.className = 'msg' + (type ? ' ' + type : '');
  },
  esc(value) { return String(value ?? ''); },
  siteUrl() { return (window.BF_CONFIG.SITE_URL || location.origin + location.pathname).replace(/\/?$/, '/'); },
  profileUrl(tag) { return this.siteUrl() + 'mascota/?id=' + encodeURIComponent(tag); },
  async requireAdmin() {
    const db = window.BF;
    if (!db) throw new Error('Falta configurar Supabase en js/config.js.');
    const { data: s, error: se } = await db.auth.getSession();
    if (se || !s.session) { location.replace('../acceso/'); throw new Error('Sesión no iniciada.'); }
    const { data: row, error } = await db.from('admin_users').select('user_id').eq('user_id', s.session.user.id).maybeSingle();
    if (error || !row) { await db.auth.signOut(); location.replace('../acceso/'); throw new Error('Este usuario no tiene permisos de administración.'); }
    return s.session.user;
  }
};
