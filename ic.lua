local ROOT="/international_code"
if not fs.exists(ROOT.."/common.lua") then error("Installation incomplete. Relancez install.lua",0) end
local common=dofile(ROOT.."/common.lua")
local args={...}
local cmd=args[1]

local function help()
  print("UNS International Code / ComputerCraft v"..common.VERSION)
  print("")
  print("ic                         Ouvrir le bureau")
  print("ic server                  Lancer le serveur de stockage")
  print("ic setup server            Configurer ce PC comme serveur")
  print("ic setup writer            Appairer un poste de redaction")
  print("ic setup clerk             Appairer un greffe")
  print("ic setup judge             Appairer un poste de juge")
  print("ic setup viewer            Appairer un lecteur")
  print("ic setup admin             Appairer un poste administrateur")
  print("ic pair <role>             Creer un code (serveur arrete)")
  print("ic backup                  Backup manuel (serveur)")
  print("ic doctor                  Diagnostic terminal/reseau")
  print("ic help                    Afficher cette aide")
end

if cmd=="help" or cmd=="--help" or cmd=="-h" then help();return end
if cmd=="setup" then
  local role=args[2]
  if role=="server" then dofile(ROOT.."/server.lua").setupServer();return end
  if role=="writer" or role=="clerk" or role=="judge" or role=="viewer" or role=="admin" then dofile(ROOT.."/client.lua").setupClient(role);return end
  error("Role inconnu. Utilisez: server, writer, clerk, judge, viewer, admin",0)
end
if cmd=="server" then dofile(ROOT.."/server.lua").run();return end
if cmd=="pair" then dofile(ROOT.."/server.lua").manualPair(args[2] or "viewer");return end
if cmd=="backup" then dofile(ROOT.."/server.lua").backupNow();return end
if cmd=="doctor" then dofile(ROOT.."/client.lua").doctor();return end

local cfg=common.loadConfig()
if not cfg then help();return end
if cfg.role=="server" then dofile(ROOT.."/server.lua").run() else dofile(ROOT.."/client.lua").run() end
