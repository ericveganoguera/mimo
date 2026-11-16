// Configuración de Mimo en la nube (Supabase).
// La URL y la clave "anon" son públicas por diseño: la seguridad la ponen
// las reglas RLS de supabase/schema.sql. NUNCA pongas aquí la clave service_role.
// Si se dejan vacías, la app funciona solo en el dispositivo, sin cuentas.
window.MIMO_CONFIG = {
  supabaseUrl: '',
  supabaseAnonKey: '',
  // Proveedores de inicio de sesión activados en Supabase: 'google', 'apple'
  providers: ['google']
};
