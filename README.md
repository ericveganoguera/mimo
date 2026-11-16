# Mimo

App de hábitos gamificada: cuida a **Mimo**, tu criatura, cepillándote los dientes y bebiendo agua.

## Cómo funciona

- **Misiones diarias:** tres cepillados con franja horaria (mañana 6–12 h, mediodía 14–17 h, noche 20–3 h) y 2 L de agua.
- **Agua:** un vaso de 250 ml cada 30 minutos como máximo.
- **Sin días pasados:** el día termina a las 3:00 y lo que no se marca a tiempo se pierde.
- **Mimo evoluciona** con la XP: Huevo → Bebé Mimo → Mimo pequeño → Mimo → Mimo alado → Mimo real.
- **Energía:** cada misión fallada le quita 10; un día perfecto le devuelve 10. Si llega a 0, baja una etapa.
- **Jefe semanal:** el Dragón de la Placa pierde vida con cada misión.
- **Ranking:** XP de las últimas 5 semanas (de momento, solo personal).

## Instalar en Android

1. Abre la web en Chrome.
2. Menú ⋮ → **Instalar aplicación** (o **Añadir a pantalla de inicio**).

Los datos se guardan en el dispositivo (localStorage). No hay servidor.

## Estructura

- `index.html`: toda la app (HTML, CSS y JS).
- `manifest.webmanifest`: datos para instalarla como app.
- `sw.js`: service worker para que funcione sin conexión.
- `icons/`: iconos de la app.
