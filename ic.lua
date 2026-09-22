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
  print("ic setup delegate          Appairer un delegue d'Etat")
  print("ic setup viewer            Appairer un lecteur")
  print("ic setup admin             Appairer un poste administrateur")
  print("ic pair <role>             Creer un code (serveur arrete)")
  print("ic backup                  Backup manuel (serveur)")
  print("ic public                  Affichage public sur Monitor")
  print("ic display <CASE-ID>       Afficher un dossier public au tribunal")
  print("ic assembly <BILL-ID>      Tableau LIVE d'un scrutin sur Monitor")
  print("ic treaty <TREATY-ID>      Tableau LIVE des signatures d'un traite")
  print("ic verify <SCEAU>          Verifier l'authenticite d'un document")
  print("ic doctor                  Diagnostic terminal/reseau")
  print("ic update                  Mettre a jour sans perdre la configuration")
  print("ic help                    Afficher cette aide")
end

if cmd=="help" or cmd=="--help" or cmd=="-h" then help();return end
if cmd=="setup" then
  local role=args[2]
  if role=="server" then dofile(ROOT.."/server.lua").setupServer();return end
  if role=="writer" or role=="clerk" or role=="judge" or role=="delegate" or role=="viewer" or role=="admin" then dofile(ROOT.."/client.lua").setupClient(role);return end
  error("Role inconnu. Utilisez: server, writer, clerk, judge, delegate, viewer, admin",0)
end
if cmd=="server" then dofile(ROOT.."/server.lua").run();return end
if cmd=="pair" then dofile(ROOT.."/server.lua").manualPair(args[2] or "viewer");return end
if cmd=="backup" then dofile(ROOT.."/server.lua").backupNow();return end
if cmd=="public" then dofile(ROOT.."/public.lua").run();return end
if cmd=="display" then
  if not args[2] then error("Usage: ic display CASE-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").caseDisplay(args[2]);return
end
if cmd=="assembly" then
  if not args[2] then error("Usage: ic assembly BILL-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").billDisplay(args[2]);return
end
if cmd=="treaty" then
  if not args[2] then error("Usage: ic treaty TREATY-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").treatyDisplay(args[2]);return
end
if cmd=="verify" then dofile(ROOT.."/client.lua").verify(args[2] or "");return end
if cmd=="doctor" then dofile(ROOT.."/client.lua").doctor();return end
if cmd=="update" then
  local url="https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua"
  print("Mise a jour UNS International Code...")
  local ok=shell.run("wget","run",url)
  if ok then print("Mise a jour terminee. Relancez ic ou redemarrez le PC.") end
  return
end

local cfg=common.loadConfig()
if not cfg then help();return end
if cfg.role=="server" then dofile(ROOT.."/server.lua").run() else dofile(ROOT.."/client.lua").run() end
