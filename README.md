# Mimo

App de hábitos gamificada: cuida a **Mimo**, tu criatura, cepillándote los dientes y bebiendo agua.

## Cómo funciona

- **Hábitos** (cada jugador elige cuáles activar en Perfil → Mis hábitos):
  - Cepillado de dientes 3 veces, con franja horaria (6–12 h, 14–17 h, 20–3 h).
  - Agua: 2 L, en vasos de 250 ml.
  - Pasos: objetivo diario configurable; se apunta la cifra de la app de salud.
  - Leer 20 minutos: se marca con un toque.
  - Hacer la cama y ordenar cocina y comedor (a cualquier hora).
  - Fregar el baño, una vez por semana.
- **Sin días pasados:** el día termina a las 3:00 y lo que no se marca a tiempo se pierde.
- **Mimo evoluciona** con la XP: Huevo → Bebé Mimo → Mimo pequeño → Mimo → Mimo alado → Mimo real.
- **Energía:** al acabar el día depende de la parte completada: todo +10, 80 % o más +5, 50–80 % igual, menos de la mitad baja (hasta −40 si no se hace nada); una misión semanal sin hacer quita 15. Si llega a 0, Mimo baja una etapa.
- **Jefe semanal:** el Dragón de la Placa pierde vida con cada misión; su vida depende de los hábitos activos.
- **Notificaciones:** 1 hora antes de que acabe un plazo y un recordatorio diario de lo pendiente (hora configurable); se envían desde Supabase (función `notify`).
- **Ranking con amigos:** grupos con código de 6 caracteres o enlace de invitación; clasificación por XP de la semana.

## Instalar en Android

1. Abre la web en Chrome.
2. Menú ⋮ → **Instalar aplicación** (o **Añadir a pantalla de inicio**).

Los datos se guardan en el dispositivo y, si inicias sesión con Google (o Apple), se sincronizan con Supabase.
La configuración de la nube está en [`supabase/SETUP.md`](supabase/SETUP.md) y el esquema en [`supabase/schema.sql`](supabase/schema.sql).

## Estructura

- `index.html`: toda la app (HTML, CSS y JS).
- `manifest.webmanifest`: datos para instalarla como app.
- `sw.js`: service worker para que funcione sin conexión.
- `config.js`: URL y clave pública de Supabase (vacío = solo en el dispositivo).
- `vendor/supabase.js`: cliente de Supabase (v2.119.0) incluido para que funcione sin conexión.
- `supabase/`: esquema de la base de datos y guía de configuración.
- `icons/`: iconos de la app.
