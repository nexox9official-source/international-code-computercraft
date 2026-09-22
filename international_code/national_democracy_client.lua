local common=dofile("/international_code/common.lua")
local printer=dofile("/international_code/national_printer.lua")

local C={}
local cfg=nil

local function clear()
  term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
end

local function at(x,y,text,fg,bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(math.max(1,x),math.max(1,y));term.write(tostring(text or ""))
end

local function bar(title,subtitle)
  local w=term.getSize()
  term.setBackgroundColor(colors.green);term.setTextColor(colors.black)
  term.setCursorPos(1,1);term.clearLine();term.write(common.fit(" NORTH COALITION / "..title,w))
  term.setBackgroundColor(colors.black)
  if subtitle then at(2,2,common.fit(subtitle,math.max(1,w-3)),colors.lightGray) end
end

local function footer(text)
  local w,h=term.getSize()
  term.setBackgroundColor(colors.black);at(1,h,common.fit(text,w),colors.lightGray)
end

local function rpc(action,payload,timeout)
  cfg=cfg or common.loadConfig()
  if not cfg or not cfg.serverId then return nil,"Terminal non appaire." end
  common.openModems()
  local rid=tostring(os.getComputerID()).."-GE-"..tostring(common.nowMs()).."-"..common.randomToken(4)
  rednet.send(cfg.serverId,{
    kind="request",requestId=rid,clientId=cfg.clientId,token=cfg.token,
    action=action,payload=payload or {}
  },common.PROTOCOL)
  local timer=os.startTimer(timeout or 5)
  while true do
    local ev,a,b,c=os.pullEvent()
    if ev=="rednet_message" and a==cfg.serverId and c==common.PROTOCOL and
       type(b)=="table" and b.kind=="response" and b.requestId==rid then
      if b.ok then return b.data,nil end
      return nil,b.error or "Erreur serveur"
    elseif ev=="timer" and a==timer then return nil,"Serveur injoignable." end
  end
end

local function message(title,text,color)
  clear();bar(title);at(2,4,text,color or colors.white);footer("Appuyez sur une touche...");os.pullEvent("key")
end

local function prompt(label,default)
  local _,h=term.getSize()
  term.setBackgroundColor(colors.black);term.setTextColor(colors.white)
  term.setCursorPos(2,h-2);term.clearLine()
  term.write(label..(default and default~="" and " ["..tostring(default).."]" or "")..": ")
  local v=read()
  if v=="" and default~=nil then return tostring(default) end
  return v
end

local function multi(label,initial)
  clear();bar(label,"Terminez par une ligne contenant uniquement .")
  local lines={}
  if initial and initial~="" then
    for line in (initial.."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
  end
  local _,h=term.getSize()
  local y=4
  for _,line in ipairs(lines) do if y<h-3 then at(2,y,line,colors.lightGray);y=y+1 end end
  term.setCursorPos(2,math.min(y,h-3))
  while true do
    local line=read()
    if line=="." then break end
    lines[#lines+1]=line
  end
  return table.concat(lines,"\n")
end

local function menu(title,items,subtitle)
  local selected,top=1,1
  while true do
    local w,h=term.getSize()
    local first,last=4,math.max(4,h-2)
    local visible=last-first+1
    if #items==0 then
      clear();bar(title,subtitle);at(2,5,"Aucun element.",colors.lightGray);footer("Echap: retour")
      local _,k=os.pullEvent("key");if k==keys.escape or k==keys.backspace then return nil end
    else
      if selected<1 then selected=#items end
      if selected>#items then selected=1 end
      if selected<top then top=selected end
      if selected>=top+visible then top=selected-visible+1 end
      clear();bar(title,subtitle)
      local y=first
      for i=top,math.min(#items,top+visible-1) do
        local row=items[i]
        local sel=i==selected
        at(2,y,common.fit((sel and "> " or "  ")..tostring(row.text or row.id or i),math.max(1,w-3)),
          sel and colors.black or colors.white,sel and colors.lime or colors.black)
        y=y+1
      end
      footer("↑↓ naviguer  Entree selectionner  Echap retour")
      local ev,a,b,c=os.pullEvent()
      if ev=="key" then
        if a==keys.up then selected=selected-1
        elseif a==keys.down then selected=selected+1
        elseif a==keys.pageUp then selected=math.max(1,selected-visible)
        elseif a==keys.pageDown then selected=math.min(#items,selected+visible)
        elseif a==keys.enter then return items[selected]
        elseif a==keys.escape or a==keys.backspace then return nil end
      elseif ev=="mouse_scroll" then selected=selected+(a>0 and 1 or -1)
      elseif ev=="mouse_click" and c>=first and c<=last then
        local idx=top+(c-first)
        if idx>=1 and idx<=#items then selected=idx;if a==1 then return items[selected] end end
      end
    end
  end
end

local function textPage(title,sections)
  local width=math.max(20,select(1,term.getSize())-4)
  local lines={}
  for _,s in ipairs(sections or {}) do
    lines[#lines+1]="["..tostring(s.label or "").."]"
    for _,l in ipairs(common.wrap(tostring(s.text or ""),width)) do lines[#lines+1]=l end
    lines[#lines+1]=""
  end
  local top=1
  while true do
    local _,h=term.getSize()
    local visible=math.max(1,h-5)
    clear();bar(title)
    local y=3
    for i=top,math.min(#lines,top+visible-1) do at(2,y,lines[i],colors.white);y=y+1 end
    footer("↑↓ defiler  Echap retour")
    local ev,a=os.pullEvent()
    if ev=="key" then
      if a==keys.up then top=math.max(1,top-1)
      elseif a==keys.down then top=math.min(math.max(1,#lines-visible+1),top+1)
      elseif a==keys.pageUp then top=math.max(1,top-visible)
      elseif a==keys.pageDown then top=math.min(math.max(1,#lines-visible+1),top+visible)
      elseif a==keys.escape or a==keys.backspace or a==keys.enter then return end
    elseif ev=="mouse_scroll" then
      top=math.max(1,math.min(math.max(1,#lines-visible+1),top+(a>0 and 1 or -1)))
    end
  end
end

local function manager(info)
  return info and (info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="council")
end

local function officeLabel(o)
  return o=="president" and "Presidence de la Coalition" or "Conseil de la Coalition"
end

local function citizenPicker(title)
  local rows,err=rpc("NC_CITIZEN_LIST",{status="citizen"})
  if not rows then message("REGISTRE CIVIL",err,colors.red);return nil end
  local items={}
  for _,c in ipairs(rows) do items[#items+1]={text=c.id.." / "..(c.displayName or c.identity),citizen=c} end
  local p=menu(title or "CHOISIR UN CITOYEN",items,#items.." citoyen(s) actif(s)")
  return p and p.citizen or nil
end

local function candidateLines(e,ids,names,counts)
  local lines={}
  for _,id in ipairs(ids or {}) do
    lines[#lines+1]=tostring(names and names[id] or id).." / "..id..
      (counts and (" = "..tostring(counts[id] or 0).." voix") or "")
  end
  return #lines>0 and table.concat(lines,"\n") or "Aucun"
end

local function mandateDetails(m)
  while true do
    local a=menu(m.id.." - "..(m.identity or m.citizenId),{
      {text="Lire le mandat",id="read"},{text="Imprimer le mandat",id="print"}
    },officeLabel(m.office).." / "..(m.status or ""))
    if not a then return end
    if a.id=="read" then
      textPage(m.id,{
        {label="Office",text=officeLabel(m.office)},
        {label="Titulaire",text=(m.identity or "").." / "..(m.citizenId or "")},
        {label="Siege",text=tostring(m.seat or "-")},
        {label="Election source",text=m.electionId or "-"},
        {label="Periode RP",text=m.termLabel or "-"},
        {label="Statut",text=m.status or ""},
        {label="Debut",text=m.startedAt or "-"},
        {label="Fin",text=(m.endedAt or "-").." / "..(m.endReason or "-")},
        {label="Sceaux",text=(m.seal or "-").."\n"..(m.endSeal or "-")},
        {label="Journal officiel",text=m.gazetteId or "-"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.mandate(m)
      message("IMPRESSION",ok and ("Mandat imprime: "..pages.." page(s).") or pages,ok and colors.lime or colors.red)
    end
  end
end

function C.openElection(id)
  while true do
    local e,err=rpc("NC_GE_GET",{id=id})
    if not e then message("ELECTION NATIONALE",err,colors.red);return end
    local info=rpc("NC_INFO",{}) or {}
    local canManage=manager(info)
    local myCitizen=info.citizenId
    local isCandidate=false
    for _,x in ipairs(e.candidates or {}) do if x==myCitizen then isCandidate=true break end end

    local actions={{text="Lire la fiche complete",id="read"},{text="Imprimer l'election",id="print"}}
    if e.stage=="draft" and canManage then actions[#actions+1]={text="Ouvrir les candidatures",id="open_candidacy"} end
    if e.stage=="candidacy" then
      if myCitizen and not isCandidate then actions[#actions+1]={text="Me porter candidat",id="self_candidate"} end
      if myCitizen and isCandidate then actions[#actions+1]={text="Retirer ma candidature",id="withdraw"} end
      if canManage then
        actions[#actions+1]={text="Ajouter un candidat",id="candidate"}
        actions[#actions+1]={text="Ouvrir le scrutin",id="open_vote"}
      end
    elseif e.stage=="voting" or e.stage=="runoff_voting" then
      actions[#actions+1]={text="Voter / modifier mon vote",id="vote"}
      if canManage then actions[#actions+1]={text="Clore et depouiller",id="close"} end
    elseif e.stage=="runoff_ready" and canManage then
      actions[#actions+1]={text="Ouvrir le second tour",id="runoff"}
    end
    if canManage and e.stage~="concluded" and e.stage~="cancelled" and e.stage~="failed" then
      actions[#actions+1]={text="Annuler l'election",id="cancel"}
    end
    if #(e.mandateIds or {})>0 then actions[#actions+1]={text="Voir les mandats issus du scrutin",id="mandates"} end

    local a=menu(e.id.." - "..e.title,actions,officeLabel(e.office).." / "..e.stage)
    if not a then return end

    if a.id=="read" then
      local ta=e.tally or {}
      local counts=ta.counts or {}
      local runoffNames=e.runoffCandidateNames or {}
      local winners={}
      for _,cid in ipairs(e.winners or {}) do winners[#winners+1]=tostring((e.winnerNames or {})[cid] or cid).." / "..cid end
      textPage(e.id,{
        {label="Office",text=officeLabel(e.office)},
        {label="Statut",text=e.stage or ""},
        {label="Sieges",text=tostring(e.seats or 1)},
        {label="Periode de mandat",text=e.termLabel or "-"},
        {label="Description",text=e.description or ""},
        {label="Candidats",text=candidateLines(e,e.candidates,e.candidateNames,counts)},
        {label="Second tour",text=candidateLines(e,e.runoffCandidates,runoffNames,nil)},
        {label="Corps electoral",text=tostring(#(e.eligibleCitizens or {})).." citoyen(s)"},
        {label="Participation",text=ta.eligible and (tostring(ta.participation or 0).."/"..tostring(ta.eligible or 0).." / quorum "..tostring(ta.quorumRequired or 0)) or "-"},
        {label="Resultat",text=(e.result or "-").."\n"..(#winners>0 and table.concat(winners,"\n") or "Aucun elu")},
        {label="Sceaux",text=(e.seal or "-").."\n"..(e.candidacySeal or "-").."\n"..(e.voteOpenSeal or "-").."\n"..(e.runoffOpenSeal or "-").."\n"..(e.resultSeal or e.cancelSeal or "-")},
        {label="Journal officiel",text=e.gazetteId or "-"}
      })

    elseif a.id=="print" then
      local ok,pages=printer.generalElection(e)
      message("IMPRESSION",ok and ("Election imprimee: "..pages.." page(s).") or pages,ok and colors.lime or colors.red)

    elseif a.id=="open_candidacy" then
      local out,er=rpc("NC_GE_OPEN_CANDIDACY",{id=e.id})
      message("CANDIDATURES",out and "Candidatures officiellement ouvertes." or er,out and colors.lime or colors.red)

    elseif a.id=="self_candidate" then
      local out,er=rpc("NC_GE_REGISTER_CANDIDATE",{id=e.id})
      message("CANDIDATURE",out and "Votre candidature est enregistree." or er,out and colors.lime or colors.red)

    elseif a.id=="withdraw" then
      local out,er=rpc("NC_GE_WITHDRAW_CANDIDATE",{id=e.id})
      message("CANDIDATURE",out and "Candidature retiree." or er,out and colors.lime or colors.red)

    elseif a.id=="candidate" then
      local cit=citizenPicker("AJOUTER UN CANDIDAT")
      if cit then
        local out,er=rpc("NC_GE_REGISTER_CANDIDATE",{id=e.id,citizenId=cit.id})
        message("CANDIDATURE",out and (cit.displayName.." est candidat.") or er,out and colors.lime or colors.red)
      end

    elseif a.id=="open_vote" then
      local out,er=rpc("NC_GE_OPEN_VOTE",{id=e.id})
      message("SCRUTIN",out and "Corps electoral fige et vote ouvert." or er,out and colors.lime or colors.red)

    elseif a.id=="vote" then
      local ids=e.stage=="runoff_voting" and (e.runoffCandidates or {}) or (e.candidates or {})
      local names=e.stage=="runoff_voting" and (e.runoffCandidateNames or {}) or (e.candidateNames or {})
      local items={{text="ABSTENTION",choice="abstain"}}
      for _,cid in ipairs(ids) do items[#items+1]={text=tostring(names[cid] or cid).." / "..cid,choice=cid} end
      local v=menu("BULLETIN DE VOTE",items,"Une voix par NC-CIT. Le dernier vote remplace le precedent.")
      if v then
        local out,er=rpc("NC_GE_VOTE",{id=e.id,choice=v.choice})
        message("VOTE",out and "Vote enregistre." or er,out and colors.lime or colors.red)
      end

    elseif a.id=="close" then
      local x=menu("CLOTURER LE SCRUTIN",{{text="Confirmer le depouillement",id="yes"},{text="Annuler",id="no"}})
      if x and x.id=="yes" then
        local out,er=rpc("NC_GE_CLOSE_VOTE",{id=e.id})
        message("RESULTAT",out and ("Statut: "..tostring(out.stage).." / "..tostring(out.result)) or er,out and colors.lime or colors.red)
      end

    elseif a.id=="runoff" then
      local out,er=rpc("NC_GE_OPEN_RUNOFF",{id=e.id})
      message("SECOND TOUR",out and "Second tour ouvert." or er,out and colors.lime or colors.red)

    elseif a.id=="cancel" then
      local reason=multi("MOTIF D'ANNULATION","")
      local out,er=rpc("NC_GE_CANCEL",{id=e.id,reason=reason})
      message("ELECTION",out and "Election annulee et scellee." or er,out and colors.lime or colors.red)

    elseif a.id=="mandates" then
      local rows=rpc("NC_MANDATE_LIST",{}) or {}
      local wanted={}
      for _,mid in ipairs(e.mandateIds or {}) do wanted[mid]=true end
      local items={}
      for _,m in ipairs(rows) do if wanted[m.id] then items[#items+1]={text=m.id.." "..(m.identity or "").." / "..m.status,mandate=m} end end
      local x=menu("MANDATS ISSUS DE "..e.id,items,#items.." mandat(s)")
      if x then mandateDetails(x.mandate) end
    end
  end
end

local function createElection(info)
  local office=menu("OFFICE A RENOUVELER",{
    {text="Presidence de la Coalition",v="president"},
    {text="Conseil de la Coalition",v="council"}
  })
  if not office then return end
  local seats=1
  if office.v=="council" then
    seats=tonumber(prompt("Nombre de sieges",tostring(info.defaultCouncilSeats or 5))) or 5
  end
  local title=prompt("Titre du scrutin",office.v=="president" and "Election presidentielle" or "Election du Conseil")
  local termLabel=prompt("Periode / mandat RP","Mandat ordinaire")
  local description=multi("DESCRIPTION / REGLES COMPLEMENTAIRES","")
  local out,err=rpc("NC_GE_CREATE",{office=office.v,seats=seats,title=title,termLabel=termLabel,description=description})
  message("ELECTION",out and ("Creee: "..out.id) or err,out and colors.lime or colors.red)
end

local function electionsScreen(info)
  local stage=""
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local rows,err=rpc("NC_GE_LIST",{stage=stage})
    if not rows then message("ELECTIONS NATIONALES",err,colors.red);return end
    local items={}
    if manager(info) then items[#items+1]={text="[+] Organiser une election nationale",id="new"} end
    items[#items+1]={text="[S] Filtrer par phase"..(stage~="" and (" ["..stage.."]") or ""),id="stage"}
    for _,e in ipairs(rows) do
      items[#items+1]={text=e.id.." ["..e.stage.."] "..e.title.." / "..officeLabel(e.office),election=e}
    end
    local p=menu("ELECTIONS NATIONALES",items,#rows.." scrutin(s)")
    if not p then return end
    if p.id=="new" then createElection(info)
    elseif p.id=="stage" then
      local s=menu("PHASE",{
        {text="Toutes",v=""},{text="Brouillons",v="draft"},{text="Candidatures",v="candidacy"},
        {text="Vote",v="voting"},{text="Second tour a ouvrir",v="runoff_ready"},
        {text="Second tour",v="runoff_voting"},{text="Conclues",v="concluded"},
        {text="Echouees",v="failed"},{text="Annulees",v="cancelled"}
      })
      if s then stage=s.v end
    elseif p.election then C.openElection(p.election.id) end
  end
end

local function mandatesScreen()
  local office=""
  while true do
    local rows,err=rpc("NC_MANDATE_LIST",{office=office})
    if not rows then message("MANDATS",err,colors.red);return end
    local items={{text="[F] Filtrer office"..(office~="" and (" ["..office.."]") or ""),id="filter"}}
    for _,m in ipairs(rows) do
      items[#items+1]={text=m.id.." ["..m.status.."] "..(m.identity or m.citizenId).." / "..officeLabel(m.office),mandate=m}
    end
    local p=menu("MANDATS NATIONAUX",items,#rows.." mandat(s)")
    if not p then return end
    if p.id=="filter" then
      local x=menu("OFFICE",{{text="Tous",v=""},{text="Presidence",v="president"},{text="Conseil",v="council"}})
      if x then office=x.v end
    elseif p.mandate then mandateDetails(p.mandate) end
  end
end

function C.run()
  cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  common.openModems()
  local info,err=rpc("NC_INFO",{})
  if not info then message("ELECTIONS",err or "Acces refuse.",colors.red);return end

  while true do
    info=rpc("NC_INFO",{}) or info
    local rows=rpc("NC_GE_LIST",{}) or {}
    local active=0
    for _,e in ipairs(rows) do
      if e.stage=="candidacy" or e.stage=="voting" or e.stage=="runoff_ready" or e.stage=="runoff_voting" then active=active+1 end
    end
    local p=menu("DEMOCRATIE NATIONALE",{
      {text="ELECTIONS PRESIDENCE / CONSEIL",id="elections"},
      {text="REGISTRE DES MANDATS",id="mandates"},
      {text="REGLES ELECTORALES",id="rules"}
    },"President: "..tostring(info.presidentIdentity or "-").." / "..active.." scrutin(s) actif(s)")
    if not p then return end
    if p.id=="elections" then electionsScreen(info)
    elseif p.id=="mandates" then mandatesScreen()
    elseif p.id=="rules" then
      textPage("REGLES ELECTORALES",{
        {label="Electeurs",text="Seuls les NC-CIT au statut citizen au moment de l'ouverture du vote appartiennent au corps electoral. Cette liste est ensuite figee."},
        {label="Vote",text="Une seule voix par NC-CIT. Plusieurs terminaux rattaches au meme citoyen ne creent jamais plusieurs voix. Le dernier vote avant cloture remplace le precedent."},
        {label="Quorum",text="Participation minimale: 50 % des citoyens eligibles, arrondie au nombre entier superieur."},
        {label="Presidence",text="Au premier tour, un candidat doit obtenir plus de 50 % des suffrages valides. Sinon les deux premiers passent au second tour. Le second tour departage a la pluralite; une egalite finale rend le scrutin non concluant."},
        {label="Conseil",text="Les candidats sont classes au nombre de voix. Les N premiers obtiennent les sieges. Une egalite au seuil du dernier siege declenche un second tour limite aux candidats a egalite."},
        {label="Incompatibilites",text="Un titulaire de portefeuille ministeriel, un juge, procureur, policier ou agent administratif ne peut pas etre candidat tant que sa fonction incompatible est active."},
        {label="Fondateur",text="La Presidence fondatrice de NexoFr_ reste en fonction tant qu'aucune election presidentielle conclue n'a transfere regulierement le mandat."}
      })
    end
  end
end

return C
