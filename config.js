// Configuración de Mimo en la nube (Supabase).
// La URL y la clave "anon" son públicas por diseño: la seguridad la ponen
// las reglas RLS de supabase/schema.sql. NUNCA pongas aquí la clave service_role.
// Si se dejan vacías, la app funciona solo en el dispositivo, sin cuentas.
window.MIMO_CONFIG = {
  supabaseUrl: 'https://vinwwwwdsqkgwyjqiaag.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpbnd3d3dkc3FrZ3d5anFpYWFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4MjczNjUsImV4cCI6MjExMDQwMzM2NX0.pDVnBWggKnnS3KboG6u6D7x8qB09TFtlGHV1hAJ2vKE',
  // Proveedores de inicio de sesión activados en Supabase: 'google', 'apple'
  providers: ['google']
};
