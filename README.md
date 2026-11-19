# PUKIBA Defense

Tower defense para Android, en cuadrícula y ambientado en un mundo de fantasía medieval. Está hecho con **Godot 4.3** y GDScript.
Se juega en **vertical**, sobre un **tablero 3D** por casillas (estilo del tutorial *Tower Defense* de Catlike Coding). Los enemigos avanzan hacia un castillo feudal europeo.
Todo el arte (torres, personajes, paisaje, iconos) se construye por código, así que el proyecto no necesita assets externos. Si quieres, puedes reemplazarlo por modelos `.glb`.

## Contenido

| Sistema | Detalle |
|---|---|
| **Mapas** | 20 mapas de 500 oleadas, cada uno con **temática única**: pradera, bosque, pantano, cementerio, glaciar, desierto, volcán, islas flotantes, abismo y otros. Los tableros van de 11×18 a 13×24 casillas. Tienen **1 a 3 entradas que se juntan** en un cruce, ríos con puentes, lagos y obstáculos donde no se puede construir. Alrededor hay paisaje con vida: agua animada, pájaros, molinos, humo, niebla y partículas. Para desbloquear el siguiente mapa hay que llegar a la **oleada 100** del anterior. |
| **Torres** | 15 torres con defensores humanos. Seis vienen de *Cat Tower Defence* (Arqueros, Arquero Venenoso, Maga de Fuego, Mago de Hielo, Lanzacohetes, Hechicero del Trueno) y nueve son nuevas: Trebuchet, Balista, Ballesteros, Alquimista, Mercado, Pira del Dragón, Druida, Obelisco y Santuario. Cada una tiene su mecánica: carga, congelación, veneno que ralentiza, salvas, rayo en cadena, rompe-armaduras, raíces, ejecución, aura u oro. |
| **Niveles en partida** | Del nivel 0 al 5, solo dentro del mapa actual. El nivel 5 desbloquea una **Maestría** propia de cada torre. |
| **Héroes** | 26 héroes que solo se consiguen en sobres (8 comunes, 6 poco comunes, 5 raros, 4 épicos y 3 legendarios), cada uno con su habilidad activa. Hasta **3 héroes a la vez** en el campo; se retiran con Demoler. |
| **Enemigos** | 19 tipos y 6 jefes, incluidos voladores, rápidos, blindados, etéreos, regeneradores, sanadores, invocadores, enemigos que se dividen al morir e inmunidades. |
| **Progreso permanente** | 10 mejoras globales, nivel de cada carta, **nivel de cuenta** con recompensas y **logros** por niveles. |
| **Retención** | Recompensa diaria con racha, misiones diarias, sobre gratis cada 4 h, **tesoro del castillo** (monedas aunque no juegues, hasta 8 h), hitos cada 25 oleadas y guardado automático. |
| **Monetización** | **Pase de temporada mensual** (40 niveles, camino gratis y premium a US$4.99), **oferta del día**, Sin Anuncios, pack de inicio, paquetes de gemas y sobres con probabilidades visibles. Anuncios con recompensa para revivir, duplicar monedas, el tesoro o el diario, el sobre gratis y la velocidad x3. |
| **Interfaz** | Pantalla principal simple con columna derecha (Diario, Misiones, Tienda, Pase, Tesoro, Logros) con avisos, fuente Fredoka (licencia OFL) e iconos dibujados por código. Cámara táctil: arrastrar mueve el tablero y pellizcar hace zoom. |

## Estructura

```
autoload/
  game_data.gd     Definiciones y balance (torres, héroes, enemigos, mapas, tienda, pase, logros)
  save_manager.gd  Guardado firmado en user://save.json
  meta.gd          Mejoras, cartas, sobres, diario, misiones, nivel, logros, pase, tesoro, oferta
  ads_manager.gd   Anuncios (simulados hasta que conectes un plugin de AdMob)
  iap_manager.gd   Google Play Billing (simulado en depuración)
scripts/game/      game.gd (partida, cámara, HUD), map_gen.gd (generador de mapas), scenery*.gd (paisaje y vida),
                   tower, enemy, projectile, fx, wave_gen, view3d (castillo, enemigos, proyectiles)
scripts/towers3d/  Modelos de las 15 torres (models.gd = kit de modelado, human_common.gd = defensores)
scripts/ui/        menu.gd, ui_kit.gd, ui_icon.gd, card_icon.gd
shaders/           Agua, lava, hielo, vacío, nubes, follaje, niebla, pájaros
assets/fonts/      Fredoka (OFL)
tests/             smoke_test, balance_sim, screenshot, model_preview, scenery_preview
```

**Para ajustar el balance:** el balance general está en `autoload/game_data.gd`. La curva de vida y oro de las oleadas está en `scripts/game/wave_gen.gd` (`HP_BASE`, `HP_GROWTH`), y el tamaño, las entradas y el agua de cada mapa en `MapGen.LAYOUTS`.

## Ejecutar y probar

1. Abre la carpeta en Godot 4.3 o superior y pulsa F5.
2. Para correr las pruebas automáticas:

```bash
godot --headless --path . res://tests/smoke_test.tscn                     # imprime SMOKE TEST OK
godot --headless --fixed-fps 60 --path . res://tests/balance_sim.tscn -- 0 # bot de balance, escenario 0..5
godot --path . res://tests/screenshot.tscn [-- mapa]                     # capturas en user://screens
godot --path . res://tests/model_preview.tscn [-- archer mage ...]        # modelos de torres
godot --path . res://tests/scenery_preview.tscn -- 0                       # paisaje de un mapa
```

Las pruebas usan su propio archivo de guardado, así que no tocan tu partida.

## Exportar a Android

1. En Godot, ve a **Editor → Manage Export Templates** e instala las plantillas 4.3.
2. En **Editor Settings → Export → Android**, configura la ruta del Android SDK y del JDK 17.
3. Ve a **Project → Install Android Build Template**. Esto es necesario para los plugins de anuncios y facturación.
4. En **Project → Export → Add… → Android**:
   - Activa *Use Gradle Build*.
   - Rellena *Package/Unique Name*, por ejemplo `com.tuestudio.pukibadefense`.
   - En los permisos, marca `INTERNET` y `ACCESS_NETWORK_STATE`.
   - Configura el keystore de *release*. No lo subas al repo; ya está en `.gitignore`.
5. Exporta un **AAB** para Google Play.

## Monetización: pasos para producción

### Anuncios (AdMob)

`Ads` funciona hoy con un **anuncio simulado**: una pantalla con cuenta atrás que permite probar todo el flujo. Para usar anuncios reales:

1. Instala un plugin de AdMob para Godot 4, como *godot-admob-plugin* de Poing Studios, desde la AssetLib.
2. Crea un nodo o script adaptador que implemente estos métodos y asígnalo en `Ads.backend` (por ejemplo, en un autoload):
   - `is_rewarded_ready() -> bool`
   - `show_rewarded(on_reward: Callable, on_closed: Callable)`
   - `show_interstitial()`
3. Sustituye los IDs de prueba de `ads_manager.gd` por los de tu cuenta **solo en la build final**. Probar con IDs reales puede bloquear tu cuenta de AdMob.

Límites ya implementados:
- Máximo de 15 anuncios con recompensa al día.
- Intersticiales solo a partir de la 2.ª partida y con un mínimo de 3 min entre uno y otro.
- Ningún anuncio para quien compró "Sin Anuncios", salvo los opcionales con recompensa.

### Compras (Google Play Billing)

1. Instala el plugin oficial **GodotGooglePlayBilling** compatible con tu versión de Godot y actívalo en el preset de Android.
2. En Google Play Console, crea productos in-app con estos IDs exactos:
   - `no_ads`
   - `starter_pack`
   - `gems_100`
   - `gems_550`
   - `gems_1200`
   - `gems_2600`
   - `season_pass` (consumible: se compra una vez por temporada)
3. `iap_manager.gd` usa la API de singleton del plugin: `startConnection`, `purchase`, `consumePurchase`, `acknowledgePurchase`, `queryPurchases`. **Comprueba los nombres de métodos y señales de la versión que instales.** La versión 2.x del plugin para Godot 4.2+ cambió la API.
4. **Recomendado:** valida los recibos en un servidor propio (Google Play Developer API) antes de entregar gemas. La validación local se puede piratear.

### Requisitos legales y de Google Play

- **Probabilidades de los sobres:** Google Play exige mostrar las probabilidades de los objetos aleatorios que se compran. Ya aparecen en *Tienda → Ver probabilidades*. En algunos países, como Bélgica, las cajas de botín pagadas están restringidas. Revísalo antes de publicar allí.
- **Política de privacidad:** es obligatoria con AdMob. También tienes que configurar el **consentimiento UMP** (GDPR/UE).
- **Público infantil:** si el público objetivo incluye menores de 13 años, se aplican las normas de *Families*: anuncios certificados y límites a las compras. Mi recomendación es clasificar el juego para 13+.
- Antes de publicar, cambia `SALT` en `save_manager.gd`.

## Servicios online (Nakama)

Sirven para el cooperativo por internet con emparejamiento, el ranking semanal por mapa y el guardado en la nube. Todo está en `scripts/net/online.gd` y los archivos del servidor en `server/`. Sin servidor, el juego funciona offline.

Cómo levantarlo en local y cómo publicarlo: [server/README.md](server/README.md).

Lo que tienes que hacer tú para producción:
1. Elegir dónde alojar el servidor: Heroic Cloud o un VPS con `server/docker-compose.yml`.
2. Cambiar las claves `CAMBIAR_...`.
3. Poner `HOST`, `SCHEME` y `SERVER_KEY` en `scripts/net/online.gd`.

## Firebase (notificaciones y analítica)

`scripts/net/firebase.gd` (autoload `Firebase`) busca en Android un plugin de Firebase y uno de notificaciones locales. En PC no hace nada.

- **Analítica:** registra los eventos `app_open`, `wave_cleared`, `pack_opened`, `purchase` y `ad_rewarded`.
- **Avisos locales al salir del juego:**
  - tesoro lleno,
  - sobre de regalo listo (cada 12 h),
  - sobre por anuncio listo (cada 3 h),
  - racha a punto de perderse (al día siguiente a las 18:00).

  Se cancelan al volver al juego.

Lo que tienes que hacer tú:
1. Crear un proyecto en https://console.firebase.google.com y añadir la app Android con el mismo nombre de paquete que el preset de exportación.
2. Descargar `google-services.json` y colocarlo donde indique el plugin (normalmente `android/build/`).
3. Instalar un plugin de Firebase para Godot 4 Android (Analytics y Cloud Messaging) y un plugin de notificaciones locales. Actívalos en el preset de Android (*Use Gradle Build*).
4. Si el plugin usa otro nombre de singleton o de métodos, ajusta las listas `*_SINGLETONS` y las llamadas en `firebase.gd`.
5. Pedir el permiso de notificaciones (`Firebase.request_push_permission()`) después de que el jugador entienda para qué sirven, como recomienda la biblia de monetización.

## Próximos pasos sugeridos

- Sprites, música y efectos de sonido. Los ajustes de sonido ya existen en el guardado.
- Pase de temporada o VIP, eventos semanales y tabla de clasificación (Google Play Games).
- Guardado en la nube para que el progreso no se pierda al cambiar de móvil.

## Recursos gratuitos y licencias

Todo lo que usa el juego es gratuito y permite venderlo sin regalías ni comisiones
(la única comisión es la estándar de la tienda, p. ej. Google Play, sobre las compras):

| Recurso | Licencia |
|---|---|
| Godot Engine 4.3 | MIT (el aviso se muestra en Configuración > Licencias) |
| Fuente Fredoka | SIL OFL 1.1 |
| Cliente Nakama para Godot | Apache 2.0 |
| Texturas de suelo (Poly Haven: sparse_grass, dirt) | CC0 |
| Música (RandomMind, OpenGameArt: The Old Tower Inn, Battle, Market Day, Victory, Defeat) | CC0 |
| Efectos de sonido | sintetizados por código (originales) |
| Shaders de contorno y suelo | propios |
| Google Play Juegos (plugin "Godot Play Game Services") | MIT, a instalar al exportar a Android |

Documentos legales en `assets/legal/` (Términos, Privacidad, Licencias). Antes de publicar,
rellena `[NOMBRE DEL TITULAR]`, `[PAÍS]` y `[CORREO DE CONTACTO]` y hazlos revisar por un
abogado. Al crear el preset de exportación añade `assets/legal/*.txt` en
"Filtros para exportar archivos que no son recursos". La política de privacidad debe
publicarse también en una URL para la ficha de Google Play.
