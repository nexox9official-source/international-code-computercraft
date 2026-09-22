local ROOT="/international_code"
if not fs.exists(ROOT.."/common.lua") then error("Installation incomplete. Relancez install.lua",0) end
local common=dofile(ROOT.."/common.lua")
local args={...}
local cmd=args[1]

local function help()
  print("UNS + North Coalition Legal Network / ComputerCraft v"..common.VERSION)
  print("")
  print("ic                         Ouvrir le bureau international")
  print("ic nc                      Ouvrir l'intranet national North Coalition")
  print("ic nc-display              Tableau national LIVE sur Monitor")
  print("ic nc-verify <SCEAU>       Verifier un sceau officiel North Coalition")
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
  print("ic resolution <RES-ID>     Tableau LIVE d'une resolution")
  print("ic session <SESSION-ID>    Tableau LIVE d'une session")
  print("ic mission <MISSION-ID>    Tableau LIVE d'une mission")
  print("ic incident <INC-ID>       Tableau LIVE d'un incident")
  print("ic conflict <CONFLICT-ID>  Tableau LIVE d'un conflit / zones")
  print("ic situation [dimension]   Centre de situation + carte Minecraft")
  print("ic treaty <TREATY-ID>      Tableau LIVE des signatures d'un traite")
  print("ic verify <SCEAU>          Verifier l'authenticite d'un document")
  print("ic inbox                   Ouvrir le centre de notifications")
  print("ic enforcement <ENF-ID>    Tableau LIVE d'une mesure d'execution")
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
if cmd=="nc" or cmd=="national" then dofile(ROOT.."/national_client.lua").run();return end
if cmd=="nc-display" then dofile(ROOT.."/national_public.lua").run();return end
if cmd=="nc-verify" then dofile(ROOT.."/national_client.lua").verify(args[2] or "");return end
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
if cmd=="resolution" then
  if not args[2] then error("Usage: ic resolution RES-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").resolutionDisplay(args[2]);return
end
if cmd=="session" then
  if not args[2] then error("Usage: ic session SESSION-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").sessionDisplay(args[2]);return
end
if cmd=="mission" then
  if not args[2] then error("Usage: ic mission MISSION-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").missionDisplay(args[2]);return
end
if cmd=="incident" then
  if not args[2] then error("Usage: ic incident INC-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").incidentDisplay(args[2]);return
end
if cmd=="conflict" then
  if not args[2] then error("Usage: ic conflict CONFLICT-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").conflictDisplay(args[2]);return
end
if cmd=="situation" then
  dofile(ROOT.."/public.lua").situationDisplay(args[2] or "minecraft:overworld");return
end
if cmd=="treaty" then
  if not args[2] then error("Usage: ic treaty TREATY-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").treatyDisplay(args[2]);return
end
if cmd=="verify" then dofile(ROOT.."/client.lua").verify(args[2] or "");return end
if cmd=="inbox" then dofile(ROOT.."/client.lua").notifications();return end
if cmd=="enforcement" then
  if not args[2] then error("Usage: ic enforcement ENF-AAAA-0001",0) end
  dofile(ROOT.."/public.lua").enforcementDisplay(args[2]);return
end
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
