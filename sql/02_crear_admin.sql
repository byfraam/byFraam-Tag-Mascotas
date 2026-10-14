-- PASO MANUAL: primero creá el usuario en Supabase → Authentication → Users → Add user.
-- Después reemplazá admin@tudominio.com por el mismo correo y ejecutá este bloque.
insert into public.admin_users (user_id)
select id from auth.users where lower(email)=lower('admin@tudominio.com')
on conflict (user_id) do nothing;
-- Si dice INSERT 0 0, el correo no coincide con un usuario existente.
