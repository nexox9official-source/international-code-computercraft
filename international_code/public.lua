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
  fillLine(t,y," VOTES OUVERTS    "..tostring(dash.votingBills or #bills),colors.yellow);y=y+1
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
      local cases=rpc(cfg,"CASE_LIST",{visibility="public"},4) or {}
      local treaties=rpc(cfg,"TREATY_LIST",{stage="in_force"},4) or {}
      local enforcements=rpc(cfg,"ENFORCEMENT_LIST",{visibility="public"},4) or {}
      local laws=rpc(cfg,"LAW_LIST",{status="active"},4) or {}
      if page==1 then drawOverview(target,dash,states,bills,cases)
      elseif page==2 then drawStates(target,states)
      elseif page==3 then drawBills(target,bills)
      elseif page==4 then drawTreaties(target,treaties)
      elseif page==5 then drawCases(target,cases)
      elseif page==6 then drawEnforcements(target,enforcements)
      else drawLaws(target,laws) end
    end

    local timer=os.startTimer(8)
    while true do
      local ev,a=os.pullEvent()
      if ev=="timer" and a==timer then page=page%7+1 break
      elseif ev=="key" and (a==keys.q or a==keys.escape) then
        term.redirect(old);old.setBackgroundColor(colors.black);old.clear();old.setCursorPos(1,1);return
      elseif ev=="monitor_touch" then page=page%7+1 break end
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

return P
