# Servidor online (Nakama)

El juego usa [Nakama](https://heroiclabs.com/nakama) (código abierto) para:

- **Cooperativo por internet:** emparejamiento automático entre 2 jugadores.
- **Ranking semanal por mapa:** la mejor oleada de la semana, que se reinicia los lunes.
- **Guardado en la nube:** el progreso no se pierde al cambiar de móvil.

Sin servidor, el juego funciona igual (todo offline). El cooperativo por Wi‑Fi y el aliado IA no lo necesitan.

## Probar en local (Windows, sin Docker)

1. Descarga los binarios oficiales:
   - Nakama para Windows: https://github.com/heroiclabs/nakama/releases (`nakama-<versión>-windows-amd64.tar.gz`).
   - CockroachDB para Windows: https://www.cockroachlabs.com/docs/releases (`cockroach-<versión>.windows-6.2-amd64.zip`).
2. Arranca la base de datos en una terminal:
   ```
   cockroach start-single-node --insecure --listen-addr=127.0.0.1:26257 --http-addr=127.0.0.1:8090 --store=datos-cockroach
   ```
3. En otra terminal, desde esta carpeta (`server/`), prepara y arranca Nakama:
   ```
   nakama migrate up --database.address root@127.0.0.1:26257
   nakama --name pukiba --database.address root@127.0.0.1:26257 --runtime.path nakama/modules
   ```
4. Juega o lanza las pruebas desde la raíz del proyecto:
   ```
   godot --headless --path . res://tests/online_test.tscn -- basic
   godot --headless --path . res://tests/online_test.tscn -- coop     # en dos terminales a la vez
   ```
   El panel de administración está en http://127.0.0.1:7351 (usuario `admin`, contraseña `password`).

## Publicar (producción)

Opciones:

- **Heroic Cloud:** el servicio gestionado de los creadores de Nakama. Es de pago y es lo más sencillo.
- **Un VPS propio** (por ejemplo de US$5–20/mes) con Docker:
  1. Copia la carpeta `server/` al servidor.
  2. Edita `docker-compose.yml` y cambia todas las claves `CAMBIAR_...`.
  3. Ejecuta `docker compose up -d`.
  4. Pon un dominio con HTTPS delante (por ejemplo Caddy o Nginx) para el puerto 7350.

Después, en `scripts/net/online.gd` cambia `HOST`, `SCHEME` (`https`) y `SERVER_KEY` por los de tu servidor.

## Qué hay en el servidor

- `nakama/modules/pukiba.lua` crea al arrancar los rankings `map_0` … `map_19`. Son semanales (reinicio los lunes a las 00:00 UTC) y guardan la mejor oleada.
- El cooperativo usa partidas *relayed* de Nakama. El primer jugador emparejado actúa como anfitrión: ejecuta la partida y envía el estado, como en el modo por Wi‑Fi.

> Seguridad: el ranking no es "autoritativo" (el cliente envía su récord). Para evitar trampas en producción, valida los récords en un módulo del servidor (`authoritative = true` + RPC que compruebe la partida).
