# Configurar la nube de Mimo (Supabase + Google)

Mimo guarda los datos en el móvil y, si hay cuenta, los sincroniza con Supabase.
El acceso es solo con **Google** (y opcionalmente **Apple**). No hay registro con contraseña.

Mientras `config.js` esté vacío, la app funciona solo en el dispositivo, sin cuentas.

## 1. Crear el proyecto de Supabase

1. Entra en [supabase.com](https://supabase.com) y crea una cuenta (puedes usar GitHub).
2. **New project**: nombre `mimo`, una región de Europa y una contraseña de base de datos (guárdala, aunque la app no la usa).
3. Espera a que termine de crearse (1–2 minutos).

## 2. Crear las tablas

1. En el menú lateral, **SQL Editor** → **New query**.
2. Pega el contenido entero de [`schema.sql`](schema.sql) y pulsa **Run**.
3. Debe terminar sin errores. Crea las tablas, las reglas de seguridad (RLS) y las funciones.

## 3. Desactivar el registro con email y contraseña

**Authentication → Sign In / Providers → Email** → desactívalo y guarda.

## 4. Activar Google

### En Google Cloud

1. Entra en [console.cloud.google.com](https://console.cloud.google.com) y crea un proyecto `Mimo`.
2. **APIs y servicios → Pantalla de consentimiento de OAuth** (o *Google Auth Platform*):
   - Tipo de usuario: **Externo**.
   - Nombre de la app: `Mimo`, y tu email de soporte.
   - Mientras esté en modo **Prueba**, solo podrán entrar los emails que añadas como *usuarios de prueba*.
     Para que entre cualquiera, pulsa **Publicar app** (con los permisos básicos de email y perfil no hace falta verificación).
3. **Credenciales → Crear credenciales → ID de cliente de OAuth**:
   - Tipo: **Aplicación web**.
   - Orígenes autorizados de JavaScript: `https://ericveganoguera.github.io`
   - URI de redirección autorizados: la **Callback URL** que muestra Supabase en
     *Authentication → Sign In / Providers → Google* (tiene la forma `https://TU-PROYECTO.supabase.co/auth/v1/callback`).
4. Copia el **ID de cliente** y el **secreto de cliente**.

### En Supabase

**Authentication → Sign In / Providers → Google** → actívalo, pega el ID de cliente y el secreto, y guarda.

## 5. Indicar desde dónde se puede volver tras el login

**Authentication → URL Configuration**:

- **Site URL**: `https://ericveganoguera.github.io/mimo/`
- **Redirect URLs**: añade `https://ericveganoguera.github.io/mimo/`

## 6. Conectar la app

**Project Settings → API Keys** (o *Data API*): copia

- la **Project URL** (`https://xxxx.supabase.co`)
- la clave **anon** o **publishable** (pública)

y ponlas en [`config.js`](../config.js). Estas dos son públicas por diseño: lo que protege los datos son las reglas RLS.
**Nunca** pongas la clave `service_role` / `secret` en la app ni en el repositorio.

## Apple (opcional)

Iniciar sesión con Apple exige una cuenta del Apple Developer Program (de pago, anual).
Con ella: crea un *Services ID* y una *key* de Sign in with Apple, actívalo en
*Authentication → Sign In / Providers → Apple* y añade `'apple'` a `providers` en `config.js`.

## Qué se guarda

| Tabla | Contenido | Quién lo ve |
|---|---|---|
| `auth.users` (Supabase) | email, proveedor, fecha de alta, último acceso | solo el propio usuario |
| `profiles` | nombre de jugador, último uso | tú y tus compañeros de grupo |
| `day_logs` | historial diario: cepillados y vasos de agua con su hora | solo tú |
| `boss_wins` | jefes semanales derrotados | solo tú |
| `progress` | XP, nivel, etapa de Mimo, energía, rachas, XP de la semana | tú y tus compañeros de grupo |
| `groups`, `group_members` | grupos de amigos para el ranking | los miembros del grupo |

Borrar la cuenta (`delete_my_account()`) elimina todos sus datos en cascada.
