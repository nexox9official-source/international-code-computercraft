local common=dofile("/international_code/common.lua")

local L={}
local palette={
  bg=colors.black,header=colors.blue,panel=colors.gray,button=colors.lightGray,
  selected=colors.cyan,text=colors.white,dark=colors.black,muted=colors.lightGray,
  ok=colors.lime,warn=colors.yellow,bad=colors.red
}

local function fill(bg)
  term.setBackgroundColor(bg or palette.bg)
  term.setTextColor(palette.text)
  term.clear()
  term.setCursorPos(1,1)
end

local function fit(s,n)
  return common.fit(tostring(s or ""),math.max(1,n))
end

local function center(y,text,fg,bg)
  local w=term.getSize()
  text=tostring(text or "")
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(math.max(1,math.floor((w-#text)/2)+1),y)
  term.write(text)
end

local function header(title,subtitle)
  local w=term.getSize()
  term.setBackgroundColor(palette.header)
  term.setTextColor(palette.text)
  term.setCursorPos(1,1);term.clearLine()
  term.write(fit(" UNS + NORTH COALITION / "..title,w))
  term.setBackgroundColor(palette.bg)
  if subtitle then
    term.setTextColor(palette.muted)
    term.setCursorPos(2,2);term.write(fit(subtitle,w-3))
  end
end

local function menu(title,items,subtitle)
  local selected=1
  while true do
    local w,h=term.getSize()
    fill()
    header(title,subtitle)
    local maxVisible=math.max(1,h-6)
    local top=math.max(1,math.min(selected-math.floor(maxVisible/2),math.max(1,#items-maxVisible+1)))
    local bottom=math.min(#items,top+maxVisible-1)

    local rows={}
    local y=4
    for i=top,bottom do
      local active=i==selected
      term.setBackgroundColor(active and palette.selected or palette.panel)
      term.setTextColor(active and palette.dark or palette.text)
      term.setCursorPos(2,y)
      term.write(fit("  "..tostring(items[i].text or ""),math.max(1,w-3)))
      rows[y]=i
      y=y+1
    end
    term.setBackgroundColor(palette.bg)
    term.setTextColor(palette.muted)
    term.setCursorPos(2,h)
    term.write(fit("Fleches / souris / Entree   Echap: retour",math.max(1,w-2)))

    local ev,a,b=os.pullEvent()
    if ev=="key" then
      if a==keys.up then selected=math.max(1,selected-1)
      elseif a==keys.down then selected=math.min(#items,selected+1)
      elseif a==keys.pageUp then selected=math.max(1,selected-maxVisible)
      elseif a==keys.pageDown then selected=math.min(#items,selected+maxVisible)
      elseif a==keys.enter or a==keys.space then return items[selected]
      elseif a==keys.escape or a==keys.backspace then return nil end
    elseif ev=="mouse_scroll" then
      selected=math.max(1,math.min(#items,selected+(a>0 and 1 or -1)))
    elseif ev=="mouse_click" then
      local idx=rows[b]
      if idx then
        if selected==idx then return items[idx] end
        selected=idx
      end
    end
  end
end

local function message(title,lines,color)
  fill();header(title)
  local w,h=term.getSize()
  local y=4
  term.setTextColor(color or palette.text)
  if type(lines)~="table" then lines={tostring(lines or "")} end
  for _,line in ipairs(lines) do
    for _,wrapped in ipairs(common.wrap(tostring(line),math.max(10,w-4))) do
      if y>=h-1 then break end
      term.setCursorPos(2,y);term.write(wrapped);y=y+1
    end
    y=y+1
  end
  term.setTextColor(palette.muted)
  term.setCursorPos(2,h);term.write(fit("Appuyez sur une touche pour revenir",w-2))
  os.pullEvent("key")
end

local function chooseRole()
  local p=menu("ROLE DU TERMINAL",{
    {text="Administrateur / NexoFr_ / administration",role="admin"},
    {text="Redaction des lois",role="writer"},
    {text="Greffe",role="clerk"},
    {text="Juge international",role="judge"},
    {text="Delegue d'Etat",role="delegate"},
    {text="Lecteur / citoyen / poste standard",role="viewer"}
  },"Le serveur doit d'abord generer un code d'appairage pour ce role.")
  return p and p.role or nil
end

local function diagnostic()
  local cfg=common.loadConfig()
  while true do
    local modemCount=common.openModems()
    local programFiles={
      "/ic.lua","/international_code/common.lua","/international_code/launcher.lua",
      "/international_code/server.lua","/international_code/client.lua",
      "/international_code/national.lua","/international_code/national_client.lua"
    }
    local missing=0
    for _,p in ipairs(programFiles) do if not fs.exists(p) then missing=missing+1 end end

    local seedFiles=0
    for i=1,5 do
      if fs.exists(string.format("/international_code/seed/%03d.lua",i)) then seedFiles=seedFiles+1 end
    end
    local ncFiles=fs.exists("/international_code/national/corpus_meta.json") and 1 or 0
    for _,name in ipairs({"001_100","101_200","201_300","301_400"}) do
      if fs.exists("/international_code/national/articles_"..name..".json") then ncFiles=ncFiles+1 end
    end

    local configText=cfg and ((cfg.role or "?").." / "..(cfg.label or cfg.serverName or "")) or "A CONFIGURER"
    local items={
      {text="Configuration : "..configText,id="config"},
      {text="Programme : "..(missing==0 and "OK" or (missing.." fichier(s) manquant(s)")),id="program"},
      {text="Corpus UNS : "..seedFiles.."/5 fragments",id="uns"},
      {text="Corpus North Coalition : "..ncFiles.."/5 fragments",id="nc"},
      {text="Modem : "..(modemCount>0 and ("OK / "..modemCount) or "ABSENT"),id="modem"},
      {text="Espace disque libre : "..tostring(fs.getFreeSpace("/")).." octets",id="disk"}
    }
    if cfg and cfg.role=="server" then
      items[#items+1]={text="Base serveur : "..(fs.exists(common.STATE) and "presente" or "a initialiser"),id="state"}
    end
    if not cfg then items[#items+1]={text="[+] CONFIGURER CE PC MAINTENANT",id="setup"} end
    items[#items+1]={text="Retour",id="back"}

    local p=menu("DIAGNOSTIC",items,"Aucun gros corpus n'est charge en RAM pendant ce diagnostic.")
    if not p or p.id=="back" then return end
    if p.id=="config" and not cfg then return "setup" end
    if p.id=="setup" then return "setup" end
    if p.id=="nc" and ncFiles<5 then
      message("CORPUS NORTH COALITION",{
        "Installation incomplete ou ancienne.",
        "Utilisez le bouton Mettre a jour depuis le centre de controle.",
        "Le nouveau format fragmente evite le pic memoire du corpus de 740 Ko."
      },palette.warn)
    elseif p.id=="modem" and modemCount==0 then
      message("MODEM","Connectez un modem filaire ou sans-fil au PC puis relancez le diagnostic.",palette.warn)
    end
  end
end

local function setupClient(role,openNational)
  local ok,err=pcall(function() dofile("/international_code/client.lua").setupClient(role) end)
  if not ok then
    message("APPAIRAGE IMPOSSIBLE",tostring(err),palette.bad)
    return
  end
  if openNational then
    local okNc,ncErr=pcall(function() dofile("/international_code/national_client.lua").run() end)
    if not okNc then message("NORTH COALITION",tostring(ncErr),palette.bad) end
  end
end

local function setupWizard()
  while true do
    local p=menu("CONFIGURATION DU PC",{
      {text="SERVEUR CENTRAL / UNS + NORTH COALITION",id="server"},
      {text="MON PC NexoFr_ / AUTORITE NORTH COALITION",id="nexo"},
      {text="PC INTERNATIONAL OU NATIONAL / choisir un role",id="client"},
      {text="DIAGNOSTIC",id="doctor"},
      {text="Retour",id="back"}
    },"Une seule interface pour installer et appairer les postes.")
    if not p or p.id=="back" then return end
    if p.id=="server" then
      local ok,err=pcall(function() dofile("/international_code/server.lua").setupServer() end)
      if not ok then message("SERVEUR",tostring(err),palette.bad) else return end
    elseif p.id=="nexo" then
      setupClient("admin",true)
      return
    elseif p.id=="client" then
      local role=chooseRole()
      if role then setupClient(role,false);return end
    elseif p.id=="doctor" then diagnostic() end
  end
end

local function update()
  local url="https://raw.githubusercontent.com/nexox9official-source/international-code-computercraft/main/install.lua"
  fill();header("MISE A JOUR")
  term.setCursorPos(2,4);term.setTextColor(palette.text);term.write("Telechargement de la derniere version...")
  local ok=shell.run("wget","run",url,"update")
  if ok then message("MISE A JOUR","Mise a jour terminee.",palette.ok)
  else message("MISE A JOUR","Echec de la mise a jour. Verifiez HTTP et la connexion.",palette.bad) end
end

local function serverMenu(cfg)
  while true do
    local p=menu("CENTRE SERVEUR",{
      {text="LANCER LE SERVEUR",id="run"},
      {text="CREER UN CODE D'APPAIRAGE",id="pair"},
      {text="SAUVEGARDE MANUELLE",id="backup"},
      {text="DIAGNOSTIC",id="doctor"},
      {text="METTRE A JOUR",id="update"},
      {text="QUITTER",id="quit"}
    },"PC #"..os.getComputerID().." / "..tostring(cfg.serverName or "UNS-Code").." / v"..common.VERSION)
    if not p or p.id=="quit" then return end
    if p.id=="run" then return shell.run("ic","server")
    elseif p.id=="pair" then
      local role=chooseRole()
      if role then
        local ok,err=pcall(function() dofile("/international_code/server.lua").manualPair(role) end)
        if not ok then message("APPAIRAGE",tostring(err),palette.bad) else os.pullEvent("key") end
      end
    elseif p.id=="backup" then
      local ok,err=pcall(function() dofile("/international_code/server.lua").backupNow() end)
      if not ok then message("BACKUP",tostring(err),palette.bad) else os.pullEvent("key") end
    elseif p.id=="doctor" then diagnostic()
    elseif p.id=="update" then update() end
  end
end

local function clientMenu(cfg)
  while true do
    cfg=common.loadConfig() or cfg
    local items={
      {text="BUREAU INTERNATIONAL UNS",id="international"},
      {text="NORTH COALITION / INTRANET NATIONAL",id="national"},
      {text="NOTIFICATIONS",id="notices"},
      {text="DIAGNOSTIC",id="doctor"},
      {text="REAPPAIRER / CHANGER LE ROLE DE CE PC",id="repair"},
      {text="METTRE A JOUR",id="update"},
      {text="QUITTER",id="quit"}
    }
    local p=menu("CENTRE DE CONTROLE",items,
      "PC #"..os.getComputerID().." / role "..tostring(cfg.role or "?").." / v"..common.VERSION)
    if not p or p.id=="quit" then return end
    if p.id=="international" then
      local ok,err=pcall(function() dofile("/international_code/client.lua").run() end)
      if not ok then message("UNS",tostring(err),palette.bad) end
    elseif p.id=="national" then
      local ok,err=pcall(function() dofile("/international_code/national_client.lua").run() end)
      if not ok then message("NORTH COALITION",tostring(err),palette.bad) end
    elseif p.id=="notices" then
      local ok,err=pcall(function() dofile("/international_code/client.lua").notifications() end)
      if not ok then message("NOTIFICATIONS",tostring(err),palette.bad) end
    elseif p.id=="doctor" then
      local action=diagnostic()
      if action=="setup" then setupWizard() end
    elseif p.id=="repair" then
      local role=chooseRole()
      if role then setupClient(role,false) end
    elseif p.id=="update" then update() end
  end
end

L.diagnostic=diagnostic
L.setup=setupWizard

function L.run()
  while true do
    local cfg=common.loadConfig()
    if not cfg then
      local p=menu("BIENVENUE",{
        {text="CONFIGURER CE PC",id="setup"},
        {text="DIAGNOSTIC",id="doctor"},
        {text="METTRE A JOUR / REPARER LES FICHIERS",id="update"},
        {text="QUITTER",id="quit"}
      },"PC #"..os.getComputerID().." / aucune configuration - ce n'est pas une erreur")
      if not p or p.id=="quit" then fill();return end
      if p.id=="setup" then setupWizard()
      elseif p.id=="doctor" then
        local action=diagnostic()
        if action=="setup" then setupWizard() end
      elseif p.id=="update" then update() end
    elseif cfg.role=="server" then
      serverMenu(cfg);return
    else
      clientMenu(cfg);return
    end
  end
end

return L
