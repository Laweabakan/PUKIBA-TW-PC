-- Módulo del servidor Nakama para PUKIBA Defense.
-- Crea los rankings semanales (mejor oleada) de los 20 mapas al arrancar el servidor.
local nk = require("nakama")

local MAPS = 20
local WEEKLY_RESET = "0 0 * * 1" -- cada lunes a las 00:00 (UTC)

for i = 0, MAPS - 1 do
  local id = "map_" .. i
  -- authoritative = false: el cliente envía su récord (cada jugador solo puede mejorarlo).
  -- sort "desc" + operator "best": se guarda la mejor oleada de la semana.
  local ok, err = pcall(nk.leaderboard_create, id, false, "desc", "best", WEEKLY_RESET, { map = i })
  if not ok then
    nk.logger_warn(("No se pudo crear el ranking %s: %s"):format(id, tostring(err)))
  end
end

nk.logger_info("PUKIBA Defense: rankings semanales listos")
