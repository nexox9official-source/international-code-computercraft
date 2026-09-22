local common=dofile("/international_code/common.lua")
local P={}

local function openModems()
  if common.openModems()==0 then return false,"Aucun modem detecte." end
  return true
end

local function rpc(cfg,action,payload,timeout)
  if not cfg or not cfg.serverId then return nil,"Terminal non appaire." end
  local ok,err=openModems()
  if not ok then return nil,err end
  local rid=tostring(os.getComputerID()).."-PUB-"..tostring(common.nowMs()).."-"..common.randomToken(4)
  rednet.send(cfg.serverId,{
    kind="request",requestId=rid,clientId=cfg.clientId,token=cfg.token,
    action=action,payload=payload or {}
  },common.PROTOCOL)
  local timer=os.startTimer(timeout or 4)
  while true do
    local ev,a,b,c=os.pullEvent()
    if ev=="rednet_message" and a==cfg.serverId and c==common.PROTOCOL and type(b)=="table"
       and b.kind=="response" and b.requestId==rid then
      if b.ok then return b.data end
      return nil,b.error or "Erreur serveur"
    elseif ev=="timer" and a==timer then
      return nil,"Serveur injoignable."
    end
  end
end

local function findMonitor()
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name)=="monitor" then return peripheral.wrap(name),name end
  end
  return nil,nil
end

local function fillLine(t,y,text,fg,bg)
  local w=t.getSize()
  t.setCursorPos(1,y)
  t.setBackgroundColor(bg or colors.black)
  t.setTextColor(fg or colors.white)
  t.write(common.fit(text,w))
end

local function header(t,title,subtitle)
  local w=t.getSize()
  t.setBackgroundColor(colors.blue)
  t.setTextColor(colors.white)
  t.setCursorPos(1,1)
  t.write(common.fit(" UNS / "..title,w))
  if subtitle then fillLine(t,2," "..subtitle,colors.lightGray,colors.black) end
end

local function drawOffline(t,msg)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"REGISTRE PUBLIC","Connexion indisponible")
  fillLine(t,4," Serveur hors ligne",colors.red)
  fillLine(t,6," "..tostring(msg or ""),colors.lightGray)
end

local function drawOverview(t,dash,states,bills,cases)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"REGISTRE PUBLIC","Union des Nations Souveraines")
  local y=4
  fillLine(t,y," ETATS MEMBRES    "..tostring(dash.states or #states),colors.cyan);y=y+2
  fillLine(t,y," ARTICLES ACTIFS  "..tostring(dash.activeLaws or 0),colors.white);y=y+1
  fillLine(t,y," DOSSIERS PUBLICS "..tostring(dash.openCases or #cases),colors.white);y=y+1
  fillLine(t,y," SCRUTINS OUVERTS "..tostring((dash.votingBills or #bills)+(dash.votingResolutions or 0)),colors.yellow);y=y+1
  fillLine(t,y," SESSIONS LIVE    "..tostring(dash.openSessions or 0).." / "..tostring(dash.scheduledSessions or 0).." prevues",colors.cyan);y=y+1
  fillLine(t,y," MISSIONS ACTIVES "..tostring(dash.activeMissions or 0),colors.cyan);y=y+1
  fillLine(t,y," INCIDENTS ACTIFS "..tostring(dash.activeIncidents or 0)..
    ((dash.criticalIncidents or 0)>0 and (" / "..tostring(dash.criticalIncidents).." CRIT") or ""), (dash.criticalIncidents or 0)>0 and colors.red or colors.orange);y=y+1
  fillLine(t,y," EXECUTIONS ACT.  "..tostring(dash.activeEnforcements or 0),colors.orange);y=y+2
  fillLine(t,y," Revision registre: "..tostring(dash.revision or "?"),colors.lightGray);y=y+1
  fillLine(t,y," Projet juridique: "..tostring(dash.codeStatus or "?"),colors.lightGray)
  local _,h=t.getSize()
  fillLine(t,h," Affichage public / v"..common.VERSION,colors.gray)
end

local function drawStates(t,states)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"ETATS MEMBRES",#states.." membre(s) actifs")
  local _,h=t.getSize()
  local y=4
  for _,st in ipairs(states) do
    if y>=h then break end
    fillLine(t,y," "..st.id.."  "..(st.shortName or st.name or "?"),colors.white)
    y=y+1
    if st.representative and st.representative~="" and y<h then
      fillLine(t,y,"   Rep: "..st.representative,colors.lightGray)
      y=y+1
    end
  end
  fillLine(t,h," Registre officiel des Etats",colors.gray)
end

local function drawBills(t,bills)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"ASSEMBLEE","Propositions actuellement au vote")
  local _,h=t.getSize()
  local y=4
  if #bills==0 then
    fillLine(t,y," Aucun vote ouvert.",colors.lightGray)
  else
    for _,b in ipairs(bills) do
      if y>=h then break end
      fillLine(t,y," "..b.id.."  "..(b.title or ""),colors.yellow);y=y+1
      local kind="Nouvel article"
      if b.proposalType=="amendment" then kind="Amendement "..(b.targetRef or "")
      elseif b.proposalType=="ratification_bundle" then kind="Ratification groupee ("..tostring(#(b.targetRefs or {}))..")" end
      if y<h then fillLine(t,y,"   "..kind,colors.lightGray);y=y+1 end
    end
  end
  fillLine(t,h," Votes officiels UNS",colors.gray)
end

local function drawCases(t,cases)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"COUR INTERNATIONALE","Dossiers rendus publics")
  local _,h=t.getSize()
  local y=4
  if #cases==0 then
    fillLine(t,y," Aucun dossier public.",colors.lightGray)
  else
    for _,c in ipairs(cases) do
      if y>=h then break end
      fillLine(t,y," "..c.id.." ["..(c.status or "?").."]",colors.cyan);y=y+1
      if y<h then fillLine(t,y,"   "..(c.title or ""),colors.white);y=y+1 end
    end
  end
  fillLine(t,h," Cour internationale de l'Union",colors.gray)
end

local function drawResolutions(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"RESOLUTIONS","Scrutins institutionnels ouverts")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then
    fillLine(t,y," Aucune resolution au vote.",colors.lightGray)
  else
    for _,r in ipairs(rows) do
      if y>=h then break end
      fillLine(t,y," "..r.id.." ["..tostring(r.resolutionType or "?").."]",colors.yellow);y=y+1
      if y<h then fillLine(t,y,"   "..tostring(r.title or ""),colors.white);y=y+1 end
    end
  end
  fillLine(t,h," Conseil / resolutions de l'Union",colors.gray)
end

local function drawSessions(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"CALENDRIER INSTITUTIONNEL","Sessions ouvertes et programmees")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then
    fillLine(t,y," Aucune session active.",colors.lightGray)
  else
    for _,sess in ipairs(rows) do
      if y>=h then break end
      local fg=sess.status=="open" and colors.lime or colors.cyan
      fillLine(t,y," "..sess.id.." ["..tostring(sess.status or "?").."]",fg);y=y+1
      if y<h then fillLine(t,y,"   "..tostring(sess.scheduledFor or "-").." / "..tostring(sess.title or ""),colors.white);y=y+1 end
    end
  end
  fillLine(t,h," Sessions de l'Union",colors.gray)
end

local function incidentSeverityColor(severity)
  if severity=="critical" then return colors.red end
  if severity=="serious" then return colors.orange end
  if severity=="minor" then return colors.yellow end
  return colors.lightGray
end

local function drawIncidents(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"INCIDENTS INTERNATIONAUX","Incidents publics actifs")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then
    fillLine(t,y," Aucun incident public actif.",colors.lightGray)
  else
    for _,incident in ipairs(rows) do
      if y>=h then break end
      fillLine(t,y," "..incident.id.." ["..string.upper(tostring(incident.severity or "?")).."]",incidentSeverityColor(incident.severity));y=y+1
      if y<h then fillLine(t,y,"   "..tostring(incident.title or ""),colors.white);y=y+1 end
      local pos=incident.position or {}
      if pos.x and pos.z and y<h then
        fillLine(t,y,"   "..tostring(pos.dimension or "minecraft:overworld").." X"..tostring(pos.x).." Z"..tostring(pos.z),colors.lightGray);y=y+1
      end
    end
  end
  fillLine(t,h," Registre public des incidents",colors.gray)
end

local function drawMissions(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"MISSIONS INTERNATIONALES","Missions publiques actives")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then
    fillLine(t,y," Aucune mission publique active.",colors.lightGray)
  else
    for _,m in ipairs(rows) do
      if y>=h then break end
      fillLine(t,y," "..m.id.." ["..tostring(m.missionType or "?").."]",colors.cyan);y=y+1
      if y<h then fillLine(t,y,"   "..tostring(m.title or ""),colors.white);y=y+1 end
      if m.area and m.area~="" and y<h then fillLine(t,y,"   Zone: "..m.area,colors.lightGray);y=y+1 end
    end
  end
  fillLine(t,h," Missions et observateurs de l'Union",colors.gray)
end

local function drawTreaties(t,treaties)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"TRAITES EN VIGUEUR","Registre diplomatique")
  local _,h=t.getSize()
  local y=4
  if #treaties==0 then
    fillLine(t,y," Aucun traite en vigueur.",colors.lightGray)
  else
    for _,tr in ipairs(treaties) do
      if y>=h then break end
      fillLine(t,y," "..tr.id.." ["..tostring(tr.treatyType or "?").."]",colors.cyan);y=y+1
      if y<h then fillLine(t,y,"   "..tostring(tr.title or ""),colors.white);y=y+1 end
    end
  end
  fillLine(t,h," Registre des traites internationaux",colors.gray)
end

local function drawEnforcements(t,rows)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"EXECUTION DES DECISIONS","Mesures publiques actives")
  local _,h=t.getSize()
  local y=4
  if #rows==0 then
    fillLine(t,y," Aucune mesure publique active.",colors.lightGray)
  else
    for _,e in ipairs(rows) do
      if y>=h then break end
      local fg=e.status=="breached" and colors.red or (e.status=="complied" and colors.lime or colors.orange)
      fillLine(t,y," "..e.id.." ["..tostring(e.status or "?").."]",fg);y=y+1
      if y<h then fillLine(t,y,"   "..tostring(e.targetName or "").." / "..tostring(e.enforcementType or ""),colors.white);y=y+1 end
    end
  end
  fillLine(t,h," Registre public d'execution",colors.gray)
end

local function drawLaws(t,laws)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"CODE INTERNATIONAL","Selection des derniers articles actifs")
  local _,h=t.getSize()
  local y=4
  local start=math.max(1,#laws-math.floor((h-4)/2)+1)
  for i=start,#laws do
    if y>=h then break end
    local l=laws[i]
    fillLine(t,y," "..l.ref.." v"..tostring(l.version or 1),colors.cyan);y=y+1
    if y<h then fillLine(t,y,"   "..(l.title or ""),colors.white);y=y+1 end
  end
  fillLine(t,h," Code officiel / articles actifs",colors.gray)
end

function P.run()
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Ce PC doit etre un terminal appaire pour l'affichage public.",0) end

  local monitor,name=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)
  target.setCursorBlink(false)

  local page=1
  while true do
    local dash,err=rpc(cfg,"DASHBOARD",{},4)
    if not dash then
      drawOffline(target,err)
    else
      local states=rpc(cfg,"STATE_LIST",{status="member"},4) or {}
      local bills=rpc(cfg,"BILL_LIST",{stage="voting"},4) or {}
      local resolutions=rpc(cfg,"RESOLUTION_LIST",{stage="voting"},4) or {}
      local openSessions=rpc(cfg,"SESSION_LIST",{status="open"},4) or {}
      local scheduledSessions=rpc(cfg,"SESSION_LIST",{status="scheduled"},4) or {}
      local sessions={}
      for _,row in ipairs(openSessions) do sessions[#sessions+1]=row end
      for _,row in ipairs(scheduledSessions) do sessions[#sessions+1]=row end
      local missions=rpc(cfg,"MISSION_LIST",{status="active",visibility="public"},4) or {}
      local incidents={}
      for _,st in ipairs({"open","investigating","contained"}) do
        local rows=rpc(cfg,"INCIDENT_LIST",{status=st,visibility="public"},4) or {}
        for _,row in ipairs(rows) do incidents[#incidents+1]=row end
      end
      local cases=rpc(cfg,"CASE_LIST",{visibility="public"},4) or {}
      local treaties=rpc(cfg,"TREATY_LIST",{stage="in_force"},4) or {}
      local enforcements=rpc(cfg,"ENFORCEMENT_LIST",{visibility="public"},4) or {}
      local laws=rpc(cfg,"LAW_LIST",{status="active"},4) or {}
      if page==1 then drawOverview(target,dash,states,bills,cases)
      elseif page==2 then drawStates(target,states)
      elseif page==3 then drawBills(target,bills)
      elseif page==4 then drawResolutions(target,resolutions)
      elseif page==5 then drawSessions(target,sessions)
      elseif page==6 then drawMissions(target,missions)
      elseif page==7 then drawIncidents(target,incidents)
      elseif page==8 then drawTreaties(target,treaties)
      elseif page==9 then drawCases(target,cases)
      elseif page==10 then drawEnforcements(target,enforcements)
      else drawLaws(target,laws) end
    end

    local timer=os.startTimer(8)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then page=page%11+1 break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      elseif ev=="monitor_touch" then page=page%11+1 break end
    end
  end
end

function P.caseDisplay(caseId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local c,err=rpc(cfg,"CASE_GET",{id=caseId},4)
    if not c then
      drawOffline(target,err)
    else
      header(target,"COUR / "..c.id,c.title or "")
      local _,h=target.getSize()
      local y=4
      fillLine(target,y," Statut: "..tostring(c.status).." / "..tostring(c.visibility),colors.cyan);y=y+1
      fillLine(target,y," Faits "..tostring(#(c.facts or {})).." | Preuves "..tostring(#(c.evidence or {}))..
        " | Jugements "..tostring(#(c.judgments or {})),colors.lightGray);y=y+2
      fillLine(target,y," Demandeur: "..tostring(c.complainant or "-"),colors.white);y=y+1
      fillLine(target,y," Mis en cause: "..tostring(c.accused or "-"),colors.white);y=y+2

      if #(c.citedArticles or {})>0 and y<h-4 then
        fillLine(target,y," Articles: "..table.concat(c.citedArticles or {},", "),colors.lightGray);y=y+2
      end

      if c.hearings and #c.hearings>0 and y<h-3 then
        local nextH=c.hearings[#c.hearings]
        fillLine(target,y," Audience: "..tostring(nextH.scheduledFor or "-").." ["..tostring(nextH.status or "?").."]",colors.yellow);y=y+1
        fillLine(target,y," "..tostring(nextH.subject or ""),colors.lightGray);y=y+2
      end

      if c.judgments and #c.judgments>0 and y<h then
        local j=c.judgments[#c.judgments]
        fillLine(target,y," Derniere decision:",colors.cyan);y=y+1
        fillLine(target,y," "..tostring(j.verdict or ""):gsub("\n"," "),colors.white)
      end
      fillLine(target,h," LIVE / actualisation 5s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(5)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

function P.billDisplay(billId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local bill,err=rpc(cfg,"BILL_GET",{id=billId},4)
    if not bill then
      drawOffline(target,err)
    else
      local tally=bill.tally or {}
      header(target,"ASSEMBLEE / "..bill.id,bill.title or "")
      local _,h=target.getSize()
      local y=4
      fillLine(target,y," Etape: "..tostring(bill.stage).." / Tour "..tostring(bill.votingRound or 0),colors.cyan);y=y+2
      fillLine(target,y," POUR       "..tostring(tally.yes or 0),colors.lime);y=y+1
      fillLine(target,y," CONTRE     "..tostring(tally.no or 0),colors.red);y=y+1
      fillLine(target,y," ABSTENTION "..tostring(tally.abstain or 0),colors.yellow);y=y+2
      fillLine(target,y," Participation "..tostring(tally.participation or 0).."/"..tostring(tally.eligible or 0),colors.white);y=y+1
      fillLine(target,y," Quorum minimum "..tostring(tally.quorumRequired or 0)..
        " : "..(tally.quorumMet and "ATTEINT" or "NON ATTEINT"),tally.quorumMet and colors.lime or colors.orange);y=y+2

      local votes={}
      for stateId,v in pairs(bill.votes or {}) do
        votes[#votes+1]=(v.stateName or stateId).."="..string.upper(v.choice or "?")
      end
      table.sort(votes)
      for _,line in ipairs(votes) do
        if y>=h then break end
        fillLine(target,y," "..line,colors.lightGray);y=y+1
      end
      fillLine(target,h," LIVE / actualisation 3s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(3)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end


function P.treatyDisplay(treatyId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local tr,err=rpc(cfg,"TREATY_GET",{id=treatyId},4)
    if not tr then
      drawOffline(target,err)
    else
      local sig=tr.signatureStatus or {}
      header(target,"DIPLOMATIE / "..tr.id,tr.title or "")
      local _,h=target.getSize()
      local y=4
      fillLine(target,y," Statut: "..tostring(tr.stage).." / v"..tostring(tr.version or 1),colors.cyan);y=y+1
      fillLine(target,y," Type: "..tostring(tr.treatyType or "?"),colors.lightGray);y=y+2
      fillLine(target,y," Signatures: "..tostring(sig.signed or 0).."/"..tostring(sig.required or 0),sig.complete and colors.lime or colors.yellow);y=y+2

      local rows={}
      for stateId,s in pairs(tr.signatures or {}) do rows[#rows+1]={id=stateId,s=s} end
      table.sort(rows,function(a,b) return a.id<b.id end)
      for _,row in ipairs(rows) do
        if y>=h then break end
        fillLine(target,y," [SIGNE] "..(row.s.stateName or row.id),colors.lime);y=y+1
      end
      for _,stateId in ipairs(sig.missing or {}) do
        if y>=h then break end
        fillLine(target,y," [ATTENTE] "..stateId,colors.yellow);y=y+1
      end

      if tr.stage=="in_force" and y<h then
        fillLine(target,y," EN VIGUEUR depuis "..tostring(tr.effectiveAt or "-"),colors.lime)
      end
      fillLine(target,h," LIVE / actualisation 4s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(4)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

function P.enforcementDisplay(enforcementId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local e,err=rpc(cfg,"ENFORCEMENT_GET",{id=enforcementId},4)
    if not e then
      drawOffline(target,err)
    else
      header(target,"EXECUTION / "..e.id,e.targetName or "")
      local _,h=target.getSize()
      local y=4
      local statusColor=e.status=="breached" and colors.red or
        (e.status=="complied" and colors.lime or colors.orange)
      fillLine(target,y," Statut: "..tostring(e.status),statusColor);y=y+1
      fillLine(target,y," Type: "..tostring(e.enforcementType or "?"),colors.cyan);y=y+2
      if e.caseId and e.caseId~="" then fillLine(target,y," Dossier: "..e.caseId,colors.lightGray);y=y+1 end
      if e.deadline and e.deadline~="" then fillLine(target,y," Echeance: "..e.deadline,colors.yellow);y=y+1 end
      if e.amount and e.amount~="" then fillLine(target,y," Montant: "..e.amount,colors.white);y=y+1 end
      y=y+1
      if y<h then fillLine(target,y," "..tostring(e.summary or ""),colors.white);y=y+2 end

      local progress=e.progress or {}
      if #progress>0 and y<h-2 then
        local last=progress[#progress]
        fillLine(target,y," Dernier suivi:",colors.cyan);y=y+1
        fillLine(target,y," "..tostring(last.note or ""):gsub("\n"," "),colors.lightGray)
      end
      fillLine(target,h," LIVE / actualisation 5s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(5)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

function P.resolutionDisplay(resolutionId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local r,err=rpc(cfg,"RESOLUTION_GET",{id=resolutionId},4)
    if not r then
      drawOffline(target,err)
    else
      local tally=r.tally or {}
      header(target,"RESOLUTION / "..r.id,r.title or "")
      local _,h=target.getSize()
      local y=4
      fillLine(target,y," Type: "..tostring(r.resolutionType or "?"),colors.cyan);y=y+1
      fillLine(target,y," Etape: "..tostring(r.stage).." / Tour "..tostring(r.votingRound or 0),colors.lightGray);y=y+2
      fillLine(target,y," POUR       "..tostring(tally.yes or 0),colors.lime);y=y+1
      fillLine(target,y," CONTRE     "..tostring(tally.no or 0),colors.red);y=y+1
      fillLine(target,y," ABSTENTION "..tostring(tally.abstain or 0),colors.yellow);y=y+2
      fillLine(target,y," Participation "..tostring(tally.participation or 0).."/"..tostring(tally.eligible or 0),colors.white);y=y+1
      fillLine(target,y," Quorum "..tostring(tally.quorumRequired or 0).." : "..(tally.quorumMet and "ATTEINT" or "NON ATTEINT"),
        tally.quorumMet and colors.lime or colors.orange);y=y+2
      if r.targetStateId and r.targetStateId~="" and y<h then
        fillLine(target,y," Cible: "..r.targetStateId,colors.orange);y=y+1
      end
      if r.enforcementId and y<h then
        fillLine(target,y," Execution: "..r.enforcementId,colors.cyan)
      end
      fillLine(target,h," LIVE / actualisation 3s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(3)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

function P.sessionDisplay(sessionId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local sess,err=rpc(cfg,"SESSION_GET",{id=sessionId},4)
    if not sess then
      drawOffline(target,err)
    else
      header(target,"SESSION / "..sess.id,sess.title or "")
      local _,h=target.getSize()
      local y=4
      local statusColor=sess.status=="open" and colors.lime or
        (sess.status=="cancelled" and colors.red or colors.cyan)
      fillLine(target,y," Statut: "..tostring(sess.status),statusColor);y=y+1
      fillLine(target,y," Type: "..tostring(sess.sessionType or "?"),colors.lightGray);y=y+1
      fillLine(target,y," Date: "..tostring(sess.scheduledFor or "-"),colors.white);y=y+1
      fillLine(target,y," Lieu: "..tostring(sess.location or "-"),colors.white);y=y+2

      local present=0
      for _ in pairs(sess.attendance or {}) do present=present+1 end
      fillLine(target,y," Etats presents: "..present,colors.cyan);y=y+2

      for _,item in ipairs(sess.agenda or {}) do
        if y>=h then break end
        local fg=item.status=="voted" and colors.lime or
          (item.status=="discussing" and colors.yellow or colors.lightGray)
        fillLine(target,y," "..tostring(item.id or "?").." ["..tostring(item.status or "?").."] "..tostring(item.title or ""),fg)
        y=y+1
      end

      fillLine(target,h," LIVE / actualisation 3s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(3)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

function P.missionDisplay(missionId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local m,err=rpc(cfg,"MISSION_GET",{id=missionId},4)
    if not m then
      drawOffline(target,err)
    else
      header(target,"MISSION / "..m.id,m.title or "")
      local _,h=target.getSize()
      local y=4
      local statusColor=m.status=="active" and colors.lime or
        (m.status=="suspended" and colors.yellow or (m.status=="cancelled" and colors.red or colors.cyan))
      fillLine(target,y," Statut: "..tostring(m.status),statusColor);y=y+1
      fillLine(target,y," Type: "..tostring(m.missionType or "?"),colors.cyan);y=y+1
      fillLine(target,y," Zone: "..tostring(m.area or "-"),colors.white);y=y+1
      fillLine(target,y," Periode: "..tostring(m.startAt or "-").." -> "..tostring(m.endAt or "-"),colors.lightGray);y=y+2
      fillLine(target,y," Etats participants: "..tostring(#(m.participatingStates or {})),colors.cyan);y=y+1
      if m.leadStateId and m.leadStateId~="" then fillLine(target,y," Responsable: "..m.leadStateId,colors.white);y=y+1 end
      if m.commander and m.commander~="" then fillLine(target,y," Commandement: "..m.commander,colors.lightGray);y=y+2 end
      fillLine(target,y," Rapports: "..tostring(#(m.reports or {})),colors.white);y=y+1
      if m.reports and #m.reports>0 and y<h then
        local r=m.reports[#m.reports]
        fillLine(target,y," Dernier: "..tostring(r.title or r.id or ""),colors.lightGray)
      end
      fillLine(target,h," LIVE / actualisation 5s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(5)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

function P.incidentDisplay(incidentId)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)

  while true do
    target.setCursorBlink(false)
    target.setBackgroundColor(colors.black);target.clear()
    local incident,err=rpc(cfg,"INCIDENT_GET",{id=incidentId},4)
    if not incident then
      drawOffline(target,err)
    else
      header(target,"INCIDENT / "..incident.id,incident.title or "")
      local _,h=target.getSize()
      local y=4
      fillLine(target,y," Gravite: "..string.upper(tostring(incident.severity or "?")),incidentSeverityColor(incident.severity));y=y+1
      fillLine(target,y," Statut: "..tostring(incident.status or "?"),colors.cyan);y=y+1
      fillLine(target,y," Type: "..tostring(incident.incidentType or "?"),colors.lightGray);y=y+1
      local pos=incident.position or {}
      if pos.x and pos.z then
        fillLine(target,y," Pos: "..tostring(pos.dimension or "minecraft:overworld").." X"..tostring(pos.x).." Y"..tostring(pos.y or "?").." Z"..tostring(pos.z),colors.white);y=y+1
      end
      if incident.area and incident.area~="" then fillLine(target,y," Zone: "..incident.area,colors.lightGray);y=y+1 end
      y=y+1
      fillLine(target,y," "..tostring(incident.summary or ""),colors.white);y=y+2
      fillLine(target,y," Etats: "..table.concat(incident.involvedStates or {},", "),colors.cyan);y=y+1
      fillLine(target,y," SITREP: "..tostring(#(incident.reports or {})),colors.lightGray)
      fillLine(target,h," LIVE / actualisation 4s / Q pour quitter",colors.gray)
    end

    local timer=os.startTimer(4)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

local function drawSituationOverview(t,sit)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"CENTRE DE SITUATION",sit.dimension or "minecraft:overworld")
  local c=sit.counts or {}
  local y=4
  fillLine(t,y," INCIDENTS      "..tostring(c.incidents or 0), (c.incidents or 0)>0 and colors.orange or colors.lime);y=y+1
  fillLine(t,y," MISSIONS       "..tostring(c.missions or 0),colors.cyan);y=y+1
  fillLine(t,y," EXECUTIONS     "..tostring(c.enforcements or 0),colors.orange);y=y+1
  fillLine(t,y," RESOLUTIONS    "..tostring(c.resolutions or 0),colors.yellow);y=y+1
  fillLine(t,y," SESSIONS       "..tostring(c.sessions or 0),colors.cyan);y=y+2
  local critical=0
  for _,incident in ipairs(sit.incidents or {}) do if incident.severity=="critical" then critical=critical+1 end end
  fillLine(t,y," ALERTES CRITIQUES "..critical,critical>0 and colors.red or colors.lime);y=y+2
  fillLine(t,y," Points cartographies: "..tostring(#(sit.points or {})),colors.lightGray)
  local _,h=t.getSize()
  fillLine(t,h," Situation generee "..tostring(sit.generatedAt or ""),colors.gray)
end

local function drawSituationMap(t,sit)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"CARTE DE SITUATION",sit.dimension or "minecraft:overworld")
  local w,h=t.getSize()
  local points=sit.points or {}
  if #points==0 then
    fillLine(t,5," Aucun point geolocalise dans cette dimension.",colors.lightGray)
    fillLine(t,h," I=incident / M=mission",colors.gray)
    return
  end

  local minX,maxX,minZ,maxZ=nil,nil,nil,nil
  for _,p in ipairs(points) do
    if p.x and p.z then
      minX=minX and math.min(minX,p.x) or p.x
      maxX=maxX and math.max(maxX,p.x) or p.x
      minZ=minZ and math.min(minZ,p.z) or p.z
      maxZ=maxZ and math.max(maxZ,p.z) or p.z
    end
  end
  if not minX then
    fillLine(t,5," Coordonnees insuffisantes.",colors.lightGray)
    return
  end
  if minX==maxX then minX=minX-100;maxX=maxX+100 end
  if minZ==maxZ then minZ=minZ-100;maxZ=maxZ+100 end
  local padX=math.max(10,(maxX-minX)*0.08)
  local padZ=math.max(10,(maxZ-minZ)*0.08)
  minX=minX-padX;maxX=maxX+padX;minZ=minZ-padZ;maxZ=maxZ+padZ

  local left,right=2,math.max(3,w-1)
  local top,bottom=5,math.max(6,h-3)
  fillLine(t,3," X "..math.floor(minX).." -> "..math.floor(maxX).." | Z "..math.floor(minZ).." -> "..math.floor(maxZ),colors.lightGray)

  for y=top,bottom do
    t.setCursorPos(left,y);t.setTextColor(colors.gray);t.write("|")
    t.setCursorPos(right,y);t.write("|")
  end
  for x=left,right do
    t.setCursorPos(x,top);t.write("-")
    t.setCursorPos(x,bottom);t.write("-")
  end

  local occupied={}
  for _,p in ipairs(points) do
    if p.x and p.z then
      local px=left+1+math.floor((p.x-minX)/(maxX-minX)*math.max(1,right-left-2))
      local py=top+1+math.floor((p.z-minZ)/(maxZ-minZ)*math.max(1,bottom-top-2))
      px=math.max(left+1,math.min(right-1,px))
      py=math.max(top+1,math.min(bottom-1,py))
      local key=px..":"..py
      local ch=p.kind=="incident" and "I" or "M"
      local fg=p.kind=="incident" and incidentSeverityColor(p.severity) or colors.cyan
      if occupied[key] then ch="*";fg=colors.white end
      occupied[key]=true
      t.setCursorPos(px,py);t.setTextColor(fg);t.write(ch)
    end
  end
  fillLine(t,h-1," I=incident  M=mission  *=superposition",colors.lightGray)
  fillLine(t,h," Carte dynamique / coordonnees Minecraft",colors.gray)
end

local function drawSituationIncidents(t,sit)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"SITUATION / INCIDENTS",sit.dimension or "")
  local _,h=t.getSize()
  local y=4
  if #(sit.incidents or {})==0 then
    fillLine(t,y," Aucun incident actif.",colors.lime)
  else
    for _,incident in ipairs(sit.incidents or {}) do
      if y>=h then break end
      fillLine(t,y," "..incident.id.." ["..string.upper(tostring(incident.severity or "?")).."]",incidentSeverityColor(incident.severity));y=y+1
      if y<h then fillLine(t,y,"   "..tostring(incident.title or "").." / "..tostring(incident.status or ""),colors.white);y=y+1 end
    end
  end
  fillLine(t,h," Incidents visibles / actualisation automatique",colors.gray)
end

local function drawSituationMissions(t,sit)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"SITUATION / MISSIONS",sit.dimension or "")
  local _,h=t.getSize()
  local y=4
  if #(sit.missions or {})==0 then
    fillLine(t,y," Aucune mission active.",colors.lightGray)
  else
    for _,m in ipairs(sit.missions or {}) do
      if y>=h then break end
      fillLine(t,y," "..m.id.." ["..tostring(m.missionType or "?").."]",colors.cyan);y=y+1
      if y<h then fillLine(t,y,"   "..tostring(m.title or ""),colors.white);y=y+1 end
      local pos=m.position or {}
      if pos.x and pos.z and y<h then fillLine(t,y,"   X"..tostring(pos.x).." Z"..tostring(pos.z),colors.lightGray);y=y+1 end
    end
  end
  fillLine(t,h," Operations / observateurs",colors.gray)
end

local function drawSituationExecution(t,sit)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"SITUATION / EXECUTION","Sanctions et mesures actives")
  local _,h=t.getSize()
  local y=4
  if #(sit.enforcements or {})==0 then
    fillLine(t,y," Aucune mesure active visible.",colors.lightGray)
  else
    for _,e in ipairs(sit.enforcements or {}) do
      if y>=h then break end
      local fg=e.status=="breached" and colors.red or colors.orange
      fillLine(t,y," "..e.id.." ["..tostring(e.status or "?").."]",fg);y=y+1
      if y<h then fillLine(t,y,"   "..tostring(e.targetName or "").." / "..tostring(e.enforcementType or ""),colors.white);y=y+1 end
    end
  end
  fillLine(t,h," Registre d'execution",colors.gray)
end

local function drawSituationInstitutions(t,sit)
  t.setBackgroundColor(colors.black);t.clear()
  header(t,"SITUATION / INSTITUTIONS","Decisions et sessions")
  local _,h=t.getSize()
  local y=4
  for _,r in ipairs(sit.resolutions or {}) do
    if y>=h then break end
    fillLine(t,y," "..r.id.." ["..tostring(r.stage or "?").."] "..tostring(r.title or ""),colors.yellow);y=y+1
  end
  for _,sess in ipairs(sit.sessions or {}) do
    if y>=h then break end
    fillLine(t,y," "..sess.id.." ["..tostring(sess.status or "?").."] "..tostring(sess.title or ""),colors.cyan);y=y+1
  end
  if y==4 then fillLine(t,y," Aucune activite institutionnelle immediate.",colors.lightGray) end
  fillLine(t,h," UNS / centre institutionnel",colors.gray)
end

function P.situationDisplay(dimension)
  local cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  dimension=common.trim(dimension or "")
  if dimension=="" then dimension="minecraft:overworld" end

  local monitor=findMonitor()
  local old=term.current()
  local target=monitor or old
  if monitor and monitor.setTextScale then pcall(monitor.setTextScale,0.5) end
  term.redirect(target)
  local page=1

  while true do
    target.setCursorBlink(false)
    local sit,err=rpc(cfg,"SITUATION_GET",{dimension=dimension},4)
    if not sit then
      drawOffline(target,err)
    elseif page==1 then drawSituationOverview(target,sit)
    elseif page==2 then drawSituationMap(target,sit)
    elseif page==3 then drawSituationIncidents(target,sit)
    elseif page==4 then drawSituationMissions(target,sit)
    elseif page==5 then drawSituationExecution(target,sit)
    else drawSituationInstitutions(target,sit) end

    local timer=os.startTimer(5)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then page=page%6+1 break
      elseif ev=="monitor_touch" then page=page%6+1 break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      end
    end
  end
end

return P
