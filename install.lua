local REPO="https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/"
local args={...}
local requested=args[1]

local function runFile(path,...)
  if shell and shell.run then return shell.run(path,...) end
  if os and os.run then return os.run({},path,...) end
  error("Impossible d'executer "..tostring(path).." : API shell/os.run indisponible.",0)
end

local BASE={"international_code/common.lua"}
local CLIENT={
  "ic.lua","international_code/common.lua","international_code/launcher.lua",
  "international_code/client.lua","international_code/printer.lua","international_code/public.lua",
  "international_code/national_client.lua","international_code/national_democracy_client.lua",
  "international_code/national_printer.lua","international_code/national_public.lua"
}
local SERVER_BOOT={
  -- Bootstrap disque minimal: les 500 articles UNS et 400 articles NC
  -- sont lus directement depuis GitHub en memoire, fragment par fragment.
  "international_code/common.lua",
  "international_code/server.lua",
  "international_code/national.lua"
}
local SERVER_RUNTIME={
  "ic.lua","international_code/common.lua","international_code/launcher.lua",
  "international_code/server.lua","international_code/national.lua",
  "international_code/national_democracy.lua","international_code/national_services.lua",
  "international_code/national_finance.lua","international_code/national_network.lua",
  "international_code/national/corpus_meta.json"
}

local ALL_PROGRAMS={
  "ic.lua","international_code/common.lua","international_code/launcher.lua",
  "international_code/server.lua","international_code/client.lua",
  "international_code/printer.lua","international_code/public.lua",
  "international_code/national.lua","international_code/national_client.lua",
  "international_code/national_democracy.lua","international_code/national_democracy_client.lua",
  "international_code/national_printer.lua","international_code/national_public.lua",
  "international_code/national_services.lua","international_code/national_finance.lua",
  "international_code/national_network.lua"
}
local BOOT_SOURCES={
  "international_code/national/corpus_v2.json",
  "international_code/national/articles_001_100.json",
  "international_code/national/articles_101_200.json",
  "international_code/national/articles_201_300.json",
  "international_code/national/articles_301_400.json",
  "international_code/seed/001.lua","international_code/seed/002.lua","international_code/seed/003.lua",
  "international_code/seed/004.lua","international_code/seed/005.lua"
}

local function full(rel) return "/"..rel end
local function dirOf(p) return p:match("^(.*)/[^/]+$") end
local function ensure(p) if p and p~="" and not fs.exists(p) then fs.makeDir(p) end end
local function freeSpace()
  local v=fs.getFreeSpace("/")
  return type(v)=="number" and v or tostring(v)
end
local function deleteFile(rel)
  local p=full(rel)
  if fs.exists(p) and not fs.isDir(p) then fs.delete(p) end
  if fs.exists(p..".download") then fs.delete(p..".download") end
end
local function deleteMany(list)
  local freed=0
  for _,rel in ipairs(list) do
    local p=full(rel)
    if fs.exists(p) and not fs.isDir(p) then
      freed=freed+(fs.getSize(p) or 0)
      fs.delete(p)
    end
    if fs.exists(p..".download") then
      freed=freed+(fs.getSize(p..".download") or 0)
      fs.delete(p..".download")
    end
  end
  return freed
end

local function safePreCleanup()
  local freed=0

  -- Ancien corpus monolithique: 700+ Ko. Il n'est plus utilise en v0.23+.
  freed=freed+deleteMany({"international_code/national/corpus_v2.json"})

  -- Une ecriture interrompue de state.tbl peut laisser un gros .tmp.
  local stateTmp="/international_code/data/state.tbl.tmp"
  if fs.exists(stateTmp) and not fs.isDir(stateTmp) then
    freed=freed+(fs.getSize(stateTmp) or 0)
    fs.delete(stateTmp)
  end

  -- Les backups sont recreables depuis state.tbl. Sur un disque sature,
  -- on les purge avant toute mise a jour afin de proteger la base principale.
  local backups="/international_code/data/backups"
  if fs.exists(backups) and fs.isDir(backups) then
    for _,name in ipairs(fs.list(backups)) do
      local p=backups.."/"..name
      if fs.exists(p) and not fs.isDir(p) then freed=freed+(fs.getSize(p) or 0) end
      fs.delete(p)
    end
  end

  -- Restes d'un telechargement interrompu.
  for _,rel in ipairs(ALL_PROGRAMS) do
    local tmp=full(rel)..".download"
    if fs.exists(tmp) then freed=freed+(fs.getSize(tmp) or 0);fs.delete(tmp) end
  end
  for _,rel in ipairs(BOOT_SOURCES) do
    local tmp=full(rel)..".download"
    if fs.exists(tmp) then freed=freed+(fs.getSize(tmp) or 0);fs.delete(tmp) end
  end
  return freed
end

local function drawHeader(title,subtitle)
  local w=term.getSize()
  term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear()
  term.setBackgroundColor(colors.blue);term.setCursorPos(1,1);term.clearLine()
  term.write((" UNS + NORTH COALITION / "..title):sub(1,w))
  term.setBackgroundColor(colors.black)
  if subtitle then term.setTextColor(colors.lightGray);term.setCursorPos(2,2);term.write(tostring(subtitle):sub(1,math.max(1,w-2))) end
end

local function menu(title,items,subtitle)
  local selected=1
  while true do
    local w,h=term.getSize()
    drawHeader(title,subtitle)
    local rows={}
    local top=math.max(1,math.min(selected-3,math.max(1,#items-math.max(1,h-6)+1)))
    local y=4
    for i=top,math.min(#items,top+math.max(1,h-6)-1) do
      local active=i==selected
      term.setBackgroundColor(active and colors.cyan or colors.gray)
      term.setTextColor(active and colors.black or colors.white)
      term.setCursorPos(2,y);term.clearLine()
      term.write(("  "..items[i].text):sub(1,math.max(1,w-3)))
      rows[y]=i;y=y+1
    end
    term.setBackgroundColor(colors.black);term.setTextColor(colors.lightGray)
    term.setCursorPos(2,h);term.write("Fleches / souris / Entree")
    local ev,a,b=os.pullEvent()
    if ev=="key" then
      if a==keys.up then selected=math.max(1,selected-1)
      elseif a==keys.down then selected=math.min(#items,selected+1)
      elseif a==keys.enter or a==keys.space then return items[selected]
      elseif a==keys.escape then return nil end
    elseif ev=="mouse_scroll" then selected=math.max(1,math.min(#items,selected+(a>0 and 1 or -1)))
    elseif ev=="mouse_click" and rows[b] then
      if selected==rows[b] then return items[selected] end
      selected=rows[b]
    end
  end
end

local function readExistingConfig()
  local p="/international_code/config.tbl"
  if not fs.exists(p) then return nil end
  local h=fs.open(p,"r");if not h then return nil end
  local raw=h.readAll();h.close()
  local ok,v=pcall(textutils.unserialize,raw)
  return ok and type(v)=="table" and v or nil
end

local function download(rel,index,total)
  local h,err=http.get(REPO..rel)
  if not h then error("Telechargement impossible: "..rel.." / "..tostring(err),0) end
  ensure(dirOf(full(rel)))

  local target=full(rel)
  local tmp=target..".download"
  if fs.exists(tmp) then fs.delete(tmp) end

  -- Sur un disque ComputerCraft serre, conserver l'ancienne version et
  -- telecharger une seconde copie peut suffire a saturer le disque.
  -- Les fichiers programme sont recreables: on remplace donc directement.
  if fs.exists(target) and not fs.isDir(target) then fs.delete(target) end

  local out=assert(fs.open(target,"wb"))
  local bytes=0
  while true do
    local chunk=h.read(8192)
    if not chunk then break end
    local ok,writeErr=pcall(out.write,chunk)
    if not ok then
      out.close();h.close()
      if fs.exists(target) then fs.delete(target) end
      error("Espace disque insuffisant pendant "..rel.." apres "..tostring(bytes).." octets: "..tostring(writeErr),0)
    end
    bytes=bytes+#chunk
  end
  h.close();out.close()

  drawHeader("INSTALLATION",string.format("%d/%d - %s",index,total,rel))
  term.setCursorPos(2,4);term.setTextColor(colors.white);term.write(tostring(bytes).." octets")
  term.setCursorPos(2,5);term.setTextColor(colors.lightGray);term.write("Espace libre: "..tostring(freeSpace()))
  if collectgarbage then pcall(collectgarbage,"collect") end
end

local function downloadSet(files)
  for i,rel in ipairs(files) do download(rel,i,#files) end
end

local function installStartup()
  if not fs.exists("/startup") then fs.makeDir("/startup") end
  local s=assert(fs.open("/startup/90_uns_international_code.lua","w"))
  s.write([[
local function run(path,...)
  if shell and shell.run then return shell.run(path,...) end
  if os and os.run then return os.run({},path,...) end
end
if fs.exists("/ic.lua") and fs.exists("/international_code/common.lua") then
  local ok,common=pcall(dofile,"/international_code/common.lua")
  local cfg=ok and common.loadConfig() or nil
  if cfg and cfg.role=="server" then run("/ic.lua","server") else run("/ic.lua") end
end
]])
  s.close()
end

local function cleanupForClient()
  local serverOnly={
    "international_code/server.lua","international_code/national.lua",
    "international_code/national_democracy.lua","international_code/national_services.lua",
    "international_code/national_finance.lua","international_code/national_network.lua",
    "international_code/national/corpus_meta.json"
  }
  deleteMany(serverOnly)
  deleteMany(BOOT_SOURCES)
end

local function cleanupForServerBootstrap()
  local clientOnly={
    "ic.lua","international_code/launcher.lua","international_code/client.lua",
    "international_code/printer.lua","international_code/public.lua",
    "international_code/national_client.lua","international_code/national_democracy_client.lua",
    "international_code/national_printer.lua","international_code/national_public.lua",
    "international_code/national_democracy.lua","international_code/national_services.lua",
    "international_code/national_finance.lua","international_code/national_network.lua"
  }
  deleteMany(clientOnly)
  deleteMany(BOOT_SOURCES)
end

local function chooseClientRole()
  local p=menu("ROLE DU PC",{
    {text="Administrateur / NexoFr_",role="admin"},
    {text="Redaction des lois",role="writer"},
    {text="Greffe",role="clerk"},
    {text="Juge international",role="judge"},
    {text="Delegue d'Etat",role="delegate"},
    {text="Lecteur / poste standard",role="viewer"}
  },"Le serveur doit avoir cree un code pour ce role.")
  return p and p.role or nil
end

local function installClient(role,openNorthCoalition)
  cleanupForClient()
  downloadSet(CLIENT)
  installStartup()
  drawHeader("APPAIRAGE","Role: "..tostring(role))
  local ok,err=pcall(function() dofile("/international_code/client.lua").setupClient(role) end)
  if not ok then
    term.setTextColor(colors.red);print("Appairage non termine: "..tostring(err))
    print("Les fichiers sont installes. Relancez simplement: ic")
    return
  end
  if openNorthCoalition then
    pcall(function() dofile("/international_code/national_client.lua").run() end)
  else
    runFile("/ic.lua")
  end
end

local function installFreshServer()
  cleanupForServerBootstrap()
  drawHeader("SERVEUR","Phase 1/2 - creation de la base")
  downloadSet(SERVER_BOOT)

  local ok,err=pcall(function() dofile("/international_code/server.lua").setupServer() end)
  if not ok then
    error("Initialisation serveur impossible: "..tostring(err),0)
  end

  -- setupServer a deja supprime les gros fragments apres construction de state.tbl.
  drawHeader("SERVEUR","Phase 2/2 - modules permanents")
  downloadSet(SERVER_RUNTIME)
  installStartup()
  runFile("/ic.lua")
end

local function updateExisting(cfg)
  if cfg and cfg.role=="server" then
    deleteMany({
      "international_code/client.lua","international_code/printer.lua","international_code/public.lua",
      "international_code/national_client.lua","international_code/national_democracy_client.lua",
      "international_code/national_printer.lua","international_code/national_public.lua"
    })

    if not fs.exists("/international_code/data/state.tbl") then
      -- Reparation automatique d'un serveur configure mais jamais initialise.
      cleanupForServerBootstrap()
      drawHeader("REPARATION SERVEUR","Base absente - creation automatique")
      downloadSet(SERVER_BOOT)
      local ok,info=pcall(function()
        return dofile("/international_code/server.lua").initializeState()
      end)
      if not ok then error("Creation de la base serveur impossible: "..tostring(info),0) end
      drawHeader("REPARATION SERVEUR",tostring(info or "Base creee"))
    else
      -- Un serveur initialise n'a plus besoin des corpus source.
      deleteMany(BOOT_SOURCES)
    end

    downloadSet(SERVER_RUNTIME)
  else
    cleanupForClient()
    downloadSet(CLIENT)
  end
  installStartup()
  drawHeader("MISE A JOUR","Terminee")
  term.setCursorPos(2,4);term.setTextColor(colors.lime);term.write("Mise a jour terminee.")
  term.setCursorPos(2,5);term.setTextColor(colors.white);term.write("Espace libre: "..tostring(freeSpace()))
  sleep(1)
end

if not http then error("API HTTP indisponible.",0) end
local freed=safePreCleanup()
local existing=readExistingConfig()

if requested=="update" and existing then
  updateExisting(existing)
  return
end

local action
if existing then
  action=menu("INSTALLATION / REPARATION",{
    {text="Mettre a jour ce PC ("..tostring(existing.role or "?")..")",id="update"},
    {text="Reconfigurer comme serveur central",id="server"},
    {text="Reconfigurer comme PC NexoFr_",id="nexo"},
    {text="Reconfigurer comme autre PC",id="client"},
    {text="Quitter",id="quit"}
  },"Nettoyage initial: "..tostring(freed).." octets / libre "..tostring(freeSpace()))
else
  action=menu("INSTALLATION",{
    {text="SERVEUR CENTRAL / UNS + NORTH COALITION",id="server"},
    {text="MON PC NexoFr_ / AUTORITE NORTH COALITION",id="nexo"},
    {text="PC INTERNATIONAL OU NATIONAL",id="client"},
    {text="Quitter",id="quit"}
  },"Ancien corpus nettoye: "..tostring(freed).." octets / libre "..tostring(freeSpace()))
end

if not action or action.id=="quit" then return end
if action.id=="update" then updateExisting(existing)
elseif action.id=="server" then installFreshServer()
elseif action.id=="nexo" then installClient("admin",true)
elseif action.id=="client" then
  local role=chooseClientRole()
  if role then installClient(role,false) end
end
