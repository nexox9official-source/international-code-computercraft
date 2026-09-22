local common=dofile("/international_code/common.lua")
local P={}

local function rpc(cfg,action,payload,timeout)
  if not cfg or not cfg.serverId then return nil,"Terminal non appaire." end
  if common.openModems()==0 then return nil,"Aucun modem detecte." end
  local rid=tostring(os.getComputerID()).."-NCPUB-"..tostring(common.nowMs()).."-"..common.randomToken(4)
  rednet.send(cfg.serverId,{
    kind="request",requestId=rid,clientId=cfg.clientId,token=cfg.token,
    action=action,payload=payload or {}
  },common.PROTOCOL)
  local timer=os.startTimer(timeout or 4)
  while true do
    local ev,a,b,c=os.pullEvent()
    if ev=="rednet_message" and a==cfg.serverId and c==common.PROTOCOL and
       type(b)=="table" and b.kind=="response" and b.requestId==rid then
      if b.ok then return b.data,nil end
      return nil,b.error or "Erreur serveur"
    elseif ev=="timer" and a==timer then return nil,"Serveur injoignable." end
  end
end

local function findMonitor()
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name)=="monitor" then return peripheral.wrap(name),name end
  end
  return nil,nil
end

local function fill(t,y,text,fg,bg)
  local w=t.getSize()
  t.setCursorPos(1,y)
  t.setBackgroundColor(bg or colors.black)
  t.setTextColor(fg or colors.white)
  t.write(common.fit(text,w))
end

local function header(t,title,subtitle)
  local w=t.getSize()
  t.setBackgroundColor(colors.green);t.setTextColor(colors.black)
  t.setCursorPos(1,1);t.write(common.fit(" NORTH COALITION / "..title,w))
  if subtitle then fill(t,2," "..subtitle,colors.lightGray,colors.black) end
end

local function offline(t,msg)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"INTRANET","Connexion indisponible")
  fill(t,4," Serveur hors ligne ou acces refuse",colors.red)
  fill(t,6," "..tostring(msg or ""),colors.lightGray)
end

local function overview(t,info,dash)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"TABLEAU NATIONAL",dash.foundingMode and "PHASE FONDATRICE" or "REGIME NORMAL")
  local y=4
  fill(t,y," PRESIDENT        "..tostring(dash.presidentIdentity or info.presidentIdentity or "-"),colors.lime);y=y+2
  fill(t,y," CITOYENS ACTIFS  "..tostring(dash.activeCitizens or 0),colors.cyan);y=y+1
  fill(t,y," LOIS ACTIVES     "..tostring(dash.activeLaws or 0),colors.white);y=y+1
  fill(t,y," LOIS EN PROJET   "..tostring(dash.draftLaws or 0),colors.lightGray);y=y+1
  fill(t,y," CATEGORIES       "..tostring(dash.categories or 0),colors.cyan);y=y+1
  fill(t,y," CABINET          "..tostring(dash.filledMinistries or 0).."/"..tostring(dash.ministries or 0),colors.cyan);y=y+1
  fill(t,y," SESSIONS LIVE    "..tostring(dash.openSessions or 0).." / "..tostring(dash.scheduledSessions or 0).." prevues",colors.cyan);y=y+1
  fill(t,y," SCRUTINS OUVERTS "..tostring(dash.openElections or 0),colors.yellow);y=y+1
  fill(t,y," VOTES LEGISLATIFS "..tostring(dash.votingBills or 0),colors.yellow);y=y+1
  fill(t,y," DECRETS PUBLIES  "..tostring(dash.publishedDecrees or 0),colors.white);y=y+1
  fill(t,y," DOSSIERS OUVERTS "..tostring(dash.openCases or 0),colors.cyan);y=y+2
  fill(t,y," Identite terminal: "..tostring(dash.nationalIdentity or "-"),colors.lightGray)
  local _,h=t.getSize()
  fill(t,h," Intranet national / v"..common.VERSION,colors.gray)
end

local function government(t,info,ministries)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"GOUVERNEMENT","President: "..tostring(info.presidentIdentity or "-"))
  local _,h=t.getSize()
  local y=4
  for _,m in ipairs(ministries or {}) do
    if y>=h then break end
    local fg=m.holderIdentity and colors.lime or colors.yellow
    fill(t,y," "..tostring(m.code).."  "..tostring(m.name),fg);y=y+1
    if y<h then fill(t,y,"   "..(m.holderIdentity and ("Titulaire: "..m.holderIdentity) or "VACANT"),colors.lightGray);y=y+1 end
  end
  fill(t,h," Registre gouvernemental",colors.gray)
end

local function elections(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"ELECTIONS MINISTERIELLES","Scrutins actuellement ouverts")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then fill(t,y," Aucun scrutin ministeriel ouvert.",colors.lightGray)
  else
    for _,e in ipairs(rows) do
      if y>=h then break end
      fill(t,y," "..e.id.." / "..tostring(e.ministryCode or ""),colors.yellow);y=y+1
      if y<h then fill(t,y,"   "..tostring(e.title or ""),colors.white);y=y+1 end
      if y<h then
        local ta=e.tally or {}
        fill(t,y,"   Participation "..tostring(ta.participation or 0).."/"..tostring(ta.eligible or 0),colors.lightGray);y=y+1
      end
    end
  end
  fill(t,h," Vote interne North Coalition",colors.gray)
end

local function bills(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"LEGISLATION","Projets actuellement au vote")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then fill(t,y," Aucun projet au vote.",colors.lightGray)
  else
    for _,b in ipairs(rows) do
      if y>=h then break end
      fill(t,y," "..b.id.." / "..tostring(b.proposalType or ""),colors.yellow);y=y+1
      if y<h then fill(t,y,"   "..tostring(b.title or ""),colors.white);y=y+1 end
      if y<h then
        local ta=b.tally or {}
        fill(t,y,"   POUR "..tostring(ta.yes or 0).." / CONTRE "..tostring(ta.no or 0).." / ABS "..tostring(ta.abstain or 0),colors.lightGray);y=y+1
      end
    end
  end
  fill(t,h," Conseil / referendum national",colors.gray)
end

local function decrees(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"JOURNAL OFFICIEL","Decrets publies")
  local _,h=t.getSize()
  local y=4
  local shown=0
  for _,d in ipairs(rows or {}) do
    if y>=h then break end
    fill(t,y," "..d.id.." / "..(d.ministryCode~="" and d.ministryCode or "PRESIDENCE"),colors.cyan);y=y+1
    if y<h then fill(t,y,"   "..tostring(d.title or ""),colors.white);y=y+1 end
    shown=shown+1
    if shown>=math.max(1,math.floor((h-5)/2)) then break end
  end
  if shown==0 then fill(t,y," Aucun decret publie.",colors.lightGray) end
  fill(t,h," Registre des actes reglementaires",colors.gray)
end

local function sessions(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"SESSIONS NATIONALES","Conseil, Cabinet et commissions")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then
    fill(t,y," Aucune session visible.",colors.lightGray)
  else
    for _,sess in ipairs(rows) do
      if y>=h then break end
      local fg=sess.status=="open" and colors.lime or
        (sess.status=="scheduled" and colors.yellow or colors.lightGray)
      fill(t,y," "..sess.id.." ["..tostring(sess.status or "?").."]",fg);y=y+1
      if y<h then fill(t,y,"   "..tostring(sess.title or ""),colors.white);y=y+1 end
      if y<h then fill(t,y,"   "..tostring(sess.scheduledFor or "").." / "..tostring(sess.location or ""),colors.lightGray);y=y+1 end
    end
  end
  fill(t,h," Calendrier institutionnel national",colors.gray)
end

local function cases(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"JUSTICE NATIONALE","Dossiers visibles depuis ce terminal")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then
    fill(t,y," Aucun dossier visible.",colors.lightGray)
  else
    for _,case in ipairs(rows) do
      if y>=h then break end
      local fg=case.status=="appeal" and colors.yellow or
        (case.status=="judged" and colors.lime or colors.cyan)
      fill(t,y," "..case.id.." ["..tostring(case.status or "?").."]",fg);y=y+1
      if y<h then fill(t,y,"   "..tostring(case.title or ""),colors.white);y=y+1 end
      if y<h then fill(t,y,"   "..tostring(case.complainant or "-").." / "..tostring(case.accused or "-"),colors.lightGray);y=y+1 end
    end
  end
  fill(t,h," Tribunal national / acces filtre",colors.gray)
end

local function categories(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"CODE NATIONAL","Categories juridiques")
  local _,h=t.getSize()
  local y=4
  for _,cat in ipairs(rows or {}) do
    if y>=h then break end
    local c=cat.counts or {}
    fill(t,y," "..tostring(cat.code).."  "..tostring(cat.name),colors.cyan);y=y+1
    if y<h then fill(t,y,"   "..tostring(c.active or 0).." actives / "..tostring(c.draft or 0).." draft",colors.lightGray);y=y+1 end
  end
  fill(t,h," NC-CORPUS-400 / registre national",colors.gray)
end

function P.run()
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  local page=1
  while true do
    local info,err=rpc(cfg,"NC_INFO",{},4)
    local dash=info and rpc(cfg,"NC_DASHBOARD",{},4) or nil
    if not info or not dash then
      offline(target,err or "Acces national refuse")
    else
      local ministries=rpc(cfg,"NC_MINISTRY_LIST",{},4) or {}
      local electionsOpen=rpc(cfg,"NC_ELECTION_LIST",{stage="open"},4) or {}
      local billsVoting=rpc(cfg,"NC_BILL_LIST",{stage="voting"},4) or {}
      local decreesPublished=rpc(cfg,"NC_DECREE_LIST",{status="published"},4) or {}
      local visibleSessions=rpc(cfg,"NC_SESSION_LIST",{},4) or {}
      local visibleCases=rpc(cfg,"NC_CASE_LIST",{},4) or {}
      local cats=rpc(cfg,"NC_CATEGORY_LIST",{},4) or {}

      if page==1 then overview(target,info,dash)
      elseif page==2 then government(target,info,ministries)
      elseif page==3 then elections(target,electionsOpen)
      elseif page==4 then bills(target,billsVoting)
      elseif page==5 then decrees(target,decreesPublished)
      elseif page==6 then sessions(target,visibleSessions)
      elseif page==7 then cases(target,visibleCases)
      else categories(target,cats) end
    end

    local timer=os.startTimer(5)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then page=page%8+1;break
      elseif ev=="monitor_touch" then page=page%8+1;break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

return P
