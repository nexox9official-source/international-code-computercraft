local common=dofile("/international_code/common.lua")
local printer=dofile("/international_code/national_printer.lua")
local C={}
local cfg=nil

local palette={
  bg=colors.black,header=colors.green,panel=colors.gray,accent=colors.lime,
  text=colors.white,muted=colors.lightGray,warn=colors.yellow,bad=colors.red,info=colors.cyan
}

local function clear()
  term.setBackgroundColor(palette.bg);term.setTextColor(palette.text);term.clear();term.setCursorPos(1,1)
end

local function at(x,y,text,fg,bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(math.max(1,x),math.max(1,y));term.write(tostring(text or ""))
end

local function bar(title,subtitle)
  local w=term.getSize()
  term.setBackgroundColor(palette.header);term.setTextColor(colors.black)
  term.setCursorPos(1,1);term.clearLine();term.write(common.fit(" NORTH COALITION / "..title,w))
  term.setBackgroundColor(palette.bg)
  if subtitle then at(2,2,common.fit(subtitle,math.max(1,w-3)),palette.muted) end
end

local function footer(text)
  local w,h=term.getSize()
  term.setBackgroundColor(palette.bg);at(1,h,common.fit(text,w),palette.muted)
end

local function message(title,text,color)
  clear();bar(title);at(2,4,text,color or palette.text);footer("Appuyez sur une touche...");os.pullEvent("key")
end

local function rpc(action,payload,timeout)
  cfg=cfg or common.loadConfig()
  if not cfg or not cfg.serverId then return nil,"Terminal non appaire." end
  common.openModems()
  local rid=tostring(os.getComputerID()).."-NC-"..tostring(common.nowMs()).."-"..common.randomToken(5)
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
    elseif ev=="timer" and a==timer then
      return nil,"Serveur injoignable (timeout)."
    end
  end
end

local function prompt(label,default)
  local w,h=term.getSize()
  term.setBackgroundColor(palette.bg);term.setTextColor(palette.text)
  term.setCursorPos(2,h-2);term.clearLine()
  term.write(label..(default and default~="" and " ["..tostring(default).."]" or "")..": ")
  local v=read()
  if v=="" and default~=nil then return tostring(default) end
  return v
end

local function multi(label,initial)
  common.ensureLayout()
  local dir=common.ROOT.."/drafts/north_coalition"
  if not fs.exists(common.ROOT.."/drafts") then fs.makeDir(common.ROOT.."/drafts") end
  if not fs.exists(dir) then fs.makeDir(dir) end
  local path=dir.."/nc-"..os.getComputerID().."-"..common.randomToken(6)..".txt"
  common.writeAll(path,tostring(initial or ""))

  while true do
    clear();bar(label,"Editeur national - sauvegarde locale automatique")
    local raw=common.readAll(path) or ""
    local lines={}
    for line in (raw.."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
    local w,h=term.getSize()
    local max=math.max(1,h-7)
    local start=math.max(1,#lines-max+1)
    local y=4
    for i=start,#lines do
      if y>=h-2 then break end
      at(2,y,common.fit(lines[i],math.max(1,w-3)),palette.text);y=y+1
    end
    footer("E=editer  F=terminer  A=annuler (brouillon conserve)")
    local ev,key=os.pullEvent("key")
    if key==keys.e then
      shell.run("edit",path)
    elseif key==keys.f or key==keys.enter then
      local out=common.readAll(path) or ""
      fs.delete(path)
      return out
    elseif key==keys.a or key==keys.escape then
      return initial or ""
    end
  end
end

local function menu(title,items,subtitle)
  local selected=1
  local top=1
  while true do
    local w,h=term.getSize()
    local first=4
    local last=math.max(first,h-2)
    local visible=last-first+1
    if #items==0 then
      clear();bar(title,subtitle);at(2,5,"Aucun element.",palette.muted);footer("Echap: retour")
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
        local fg=i==selected and colors.black or palette.text
        local bg=i==selected and palette.accent or palette.bg
        at(2,y,common.fit((i==selected and "> " or "  ")..tostring(row.text or row.label or row.id or i),math.max(1,w-3)),fg,bg)
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
      elseif ev=="mouse_scroll" then
        selected=selected+(a>0 and 1 or -1)
      elseif ev=="mouse_click" and c>=first and c<=last then
        local idx=top+(c-first)
        if idx>=1 and idx<=#items then selected=idx;if a==1 then return items[selected] end end
      end
    end
  end
end

local function textPage(title,sections)
  local lines={}
  for _,s in ipairs(sections or {}) do
    lines[#lines+1]="["..tostring(s.label or "").."]"
    for _,l in ipairs(common.wrap(tostring(s.text or ""),math.max(20,select(1,term.getSize())-4))) do lines[#lines+1]=l end
    lines[#lines+1]=""
  end
  local top=1
  while true do
    clear();bar(title)
    local w,h=term.getSize()
    local visible=math.max(1,h-5)
    local y=3
    for i=top,math.min(#lines,top+visible-1) do at(2,y,common.fit(lines[i],math.max(1,w-3)),palette.text);y=y+1 end
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

local function roleLabel(r)
  local labels={
    admin="Administrateur",president="President de la Coalition",council="Conseil de la Coalition",
    minister="Ministre",judge="Justice",police="Police / securite",civil_servant="Administration",
    citizen="Citoyen",public="Public"
  }
  return labels[r] or tostring(r or "non autorise")
end

local function chooseStatus()
  local p=menu("STATUT DES LOIS",{
    {text="Tous",v=""},{text="Projet / draft",v="draft"},{text="En vigueur",v="active"},
    {text="Suspendu",v="suspended"},{text="Abroge",v="repealed"}
  })
  return p and p.v or ""
end

local function lawDetails(ref)
  while true do
    local law,err=rpc("NC_LAW_GET",{ref=ref})
    if not law then message("ARTICLE",err,palette.bad);return end
    local actions={{text="Lire le texte complet",id="read"},{text="Imprimer l'article",id="print"}}
    local a=menu((law.display_reference or law.id).." - "..law.title,actions,
      (law.category_code or "").." / "..(law.chapter or "").." / "..(law.status or "").." v"..tostring(law.version))
    if not a then return end
    if a.id=="read" then
      local hist={}
      for _,h in ipairs(law.history or {}) do
        hist[#hist+1]="v"..tostring(h.version or "?").." / "..tostring(h.status or "").." / "..tostring(h.author or h.archivedBy or "").." / "..tostring(h.note or h.sourceBill or "")
      end
      textPage(law.display_reference or law.id,{
        {label="Identifiant permanent",text=law.id or ""},
        {label="Branche juridique",text=law.legal_branch or ""},
        {label="Categorie / Code",text=(law.category_code or "").." / "..(law.category_name or "")},
        {label="Livre",text=law.book_title or ""},
        {label="Titre",text=(law.title_code or "").." / "..(law.title_group or "")},
        {label="Chapitre",text=(law.chapter_code or "").." / "..(law.chapter or "")},
        {label="Article",text=law.title or ""},
        {label="Nature",text=law.article_kind or ""},
        {label="Statut / version",text=(law.status or "").." / v"..tostring(law.version or "")},
        {label="Classe penale",text=law.severity or "-"},
        {label="Autorite responsable",text=law.responsible_authority or "-"},
        {label="Ministere responsable",text=law.responsible_ministry or "-"},
        {label="Texte",text=law.text or ""},
        {label="Historique",text=#hist>0 and table.concat(hist,"\n") or "Version initiale"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.law(law)
      message("IMPRESSION",ok and ("Article imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    end
  end
end

local function chooseLaw(query)
  local rows,err=rpc("NC_LAW_LIST",{query=query or ""})
  if not rows then message("CODE",err,palette.bad);return nil end
  local items={}
  for _,law in ipairs(rows) do
    items[#items+1]={text=(law.display_reference or law.id).." "..law.title.." ["..law.status.."]",law=law}
  end
  local p=menu("CHOISIR UN ARTICLE",items,#rows.." resultat(s)")
  return p and p.law or nil
end

local function categoryScreen(cat,status)
  status=status or ""
  while true do
    local rows,err=rpc("NC_LAW_LIST",{category_code=cat.code,status=status})
    if not rows then message("CODE",err,palette.bad);return end

    local titles={}
    for _,law in ipairs(rows) do
      local key=(law.title_code or "").."|"..(law.title_group or "Sans titre")
      local t=titles[key]
      if not t then t={code=law.title_code,name=law.title_group,chapters={}};titles[key]=t end
      local ck=(law.chapter_code or "").."|"..(law.chapter or "Sans chapitre")
      local ch=t.chapters[ck]
      if not ch then ch={code=law.chapter_code,name=law.chapter,laws={}};t.chapters[ck]=ch end
      ch.laws[#ch.laws+1]=law
    end

    local items={{text="[?] Rechercher dans cette categorie",id="search"},{text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}}
    local titleList={}
    for _,t in pairs(titles) do titleList[#titleList+1]=t end
    table.sort(titleList,function(a,b) return tostring(a.code)<tostring(b.code) end)
    for _,t in ipairs(titleList) do
      local count=0;for _,ch in pairs(t.chapters) do count=count+#ch.laws end
      items[#items+1]={text=(t.code or "").." / "..t.name.." ("..count..")",title=t}
    end

    local p=menu(cat.code.." - "..cat.name,items,cat.legal_branch.." / "..#rows.." article(s)")
    if not p then return end
    if p.id=="search" then
      local q=prompt("Mot, article, titre, chapitre")
      local found=rpc("NC_LAW_LIST",{query=q,category_code=cat.code,status=status}) or {}
      local list={}
      for _,law in ipairs(found) do list[#list+1]={text=(law.display_reference or law.id).." "..law.title,law=law} end
      local x=menu("RESULTATS",list,#found.." article(s)")
      if x then lawDetails(x.law.id) end
    elseif p.id=="status" then
      status=chooseStatus()
    elseif p.title then
      local chapters={}
      for _,ch in pairs(p.title.chapters) do chapters[#chapters+1]=ch end
      table.sort(chapters,function(a,b) return tostring(a.code)<tostring(b.code) end)
      local chItems={}
      for _,ch in ipairs(chapters) do chItems[#chItems+1]={text=(ch.code or "").." / "..ch.name.." ("..#ch.laws..")",chapter=ch} end
      local chosen=menu(p.title.code.." - "..p.title.name,chItems,"Choisissez un chapitre")
      if chosen then
        table.sort(chosen.chapter.laws,function(a,b) return (a.number or 0)<(b.number or 0) end)
        local lawItems={}
        for _,law in ipairs(chosen.chapter.laws) do lawItems[#lawItems+1]={text=(law.display_reference or law.id).." "..law.title.." ["..law.status.."]",law=law} end
        local law=menu(chosen.chapter.code.." - "..chosen.chapter.name,lawItems,#lawItems.." article(s)")
        if law then lawDetails(law.law.id) end
      end
    end
  end
end

local function codeScreen()
  local status=""
  while true do
    local cats,err=rpc("NC_CATEGORY_LIST",{})
    if not cats then message("CODE NATIONAL",err,palette.bad);return end
    local items={{text="[?] RECHERCHE GLOBALE DANS LE CODE",id="search"},{text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}}
    for _,cat in ipairs(cats) do
      local c=cat.counts or {}
      items[#items+1]={text=cat.code.."  "..cat.name.."  ("..tostring(c.total or 0)..")",cat=cat}
    end
    local p=menu("CODE NATIONAL",items,#cats.." categories / 400 articles initiaux")
    if not p then return end
    if p.id=="search" then
      local q=prompt("Recherche: numero, titre, mot, ministere")
      local rows=rpc("NC_LAW_LIST",{query=q,status=status}) or {}
      local list={}
      for _,law in ipairs(rows) do
        list[#list+1]={text=(law.display_reference or law.id).." "..law.title.." / "..(law.category_code or ""),law=law}
      end
      local x=menu("RECHERCHE CODE NATIONAL",list,#rows.." resultat(s)")
      if x then lawDetails(x.law.id) end
    elseif p.id=="status" then status=chooseStatus()
    elseif p.cat then categoryScreen(p.cat,status) end
  end
end

local function chooseClient(title,filter)
  local rows,err=rpc("NC_CLIENT_LIST",{})
  if not rows then message("TERMINAUX",err,palette.bad);return nil end
  local items={}
  for _,cl in ipairs(rows) do
    if not filter or filter(cl) then
      items[#items+1]={text=(cl.nationalIdentity or cl.label).." / PC #"..tostring(cl.computerId).." / "..roleLabel(cl.nationalRole),client=cl}
    end
  end
  local p=menu(title or "TERMINAUX NATIONAUX",items,#items.." terminal(aux)")
  return p and p.client or nil
end

local function ministryDetails(code)
  while true do
    local m,err=rpc("NC_MINISTRY_GET",{code=code})
    if not m then message("MINISTERE",err,palette.bad);return end
    local info=rpc("NC_INFO",{}) or {}
    local canPresident=(info.nationalRole=="admin" or info.nationalRole=="president")
    local actions={{text="Lire la fiche du ministere",id="read"},{text="Imprimer la fiche",id="print"}}
    if not m.holderClientId then
      actions[#actions+1]={text="Scrutins concernant ce ministere",id="elections"}
      if canPresident and m.directAppointmentAllowed then actions[#actions+1]={text="Nomination directe autorisee",id="appoint"} end
    else
      actions[#actions+1]={text="Titulaire: "..tostring(m.holderIdentity),id="holder"}
      if canPresident then actions[#actions+1]={text="Revoquer / liberer le portefeuille",id="remove"} end
    end
    local a=menu(m.code.." - "..m.name,actions,m.holderIdentity and ("Titulaire: "..m.holderIdentity) or "VACANT")
    if not a then return end
    if a.id=="read" then
      local hist={}
      for _,h in ipairs(m.history or {}) do hist[#hist+1]=(h.at or "").." / "..(h.event or "").." / "..(h.identity or "").." / "..(h.mode or h.reason or "") end
      textPage(m.code,{
        {label="Ministere",text=m.name or ""},
        {label="Competences",text=table.concat(m.scope or {},", ")},
        {label="Titulaire",text=m.holderIdentity or "VACANT"},
        {label="Nomination",text=(m.appointmentMode or "-").." / "..(m.appointedAt or m.vacantSince or "-")},
        {label="Scrutins echoues",text=tostring(m.failedElections or 0)},
        {label="Nomination directe",text=m.directAppointmentAllowed and ("AUTORISEE: "..tostring(m.directAppointmentReason)) or "Non ouverte"},
        {label="Sceau",text=m.appointmentSeal or "-"},
        {label="Historique",text=#hist>0 and table.concat(hist,"\n") or "Aucun"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.ministry(m);message("IMPRESSION",ok and ("Fiche imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="appoint" then
      local cl=chooseClient("CHOISIR LE MINISTRE",function(x) return x.nationalRole~="president" and not x.ministryCode end)
      if cl then
        local reason=multi("MOTIF DE NOMINATION","Nomination directe selon les regles gouvernementales.")
        local out,e=rpc("NC_MINISTER_APPOINT_DIRECT",{ministryCode=m.code,clientId=cl.clientId,reason=reason})
        message("NOMINATION",out and (cl.nationalIdentity.." nomme ministre.") or e,out and palette.accent or palette.bad)
      end
    elseif a.id=="remove" then
      local reason=multi("MOTIF OFFICIEL DE REVOCATION / DEPART","")
      local out,e=rpc("NC_MINISTER_REMOVE",{ministryCode=m.code,reason=reason})
      message("GOUVERNEMENT",out and "Portefeuille libere." or e,out and palette.accent or palette.bad)
    elseif a.id=="elections" then
      local rows=rpc("NC_ELECTION_LIST",{ministryCode=m.code}) or {}
      local items={}
      for _,e in ipairs(rows) do items[#items+1]={text=e.id.." ["..e.stage.."] "..e.title,election=e} end
      local x=menu("SCRUTINS / "..m.code,items,#rows.." scrutin(s)")
      if x then C.electionDetails(x.election.id) end
    end
  end
end

local function governmentScreen(info)
  while true do
    local gov,err=rpc("NC_GOVERNMENT_GET",{})
    if not gov then message("GOUVERNEMENT",err,palette.bad);return end
    local filled=0;for _,m in ipairs(gov.ministries or {}) do if m.holderClientId then filled=filled+1 end end
    local items={
      {text="Presidence / principes gouvernementaux",id="pres"},
      {text="Ministeres et portefeuille ("..filled.."/"..#(gov.ministries or {})..")",id="ministries"},
      {text="Scrutins ministeriels",id="elections"}
    }
    if info.nationalRole=="admin" or info.nationalRole=="president" then
      items[#items+1]={text="Gestion des terminaux / fonctions",id="clients"}
      if gov.meta.foundingMode then items[#items+1]={text="[!] Clore la phase fondatrice",id="closefounding"} end
    end
    local p=menu("GOUVERNEMENT NATIONAL",items,"President: "..tostring(gov.meta.presidentIdentity).." / "..(gov.meta.foundingMode and "PHASE FONDATRICE" or "REGIME NORMAL"))
    if not p then return end
    if p.id=="pres" then
      local gs=gov.governmentSystem or {}
      textPage("PRESIDENCE / GOUVERNEMENT",{
        {label="Chef de l'Etat",text=gs.head_of_state_title or "President de la Coalition"},
        {label="President enregistre",text=gov.meta.presidentIdentity or "-"},
        {label="Modes ministeriels",text=table.concat(gs.minister_selection_modes or {},", ")},
        {label="Regle sans vote",text=gs.default_rule or ""},
        {label="Delai",text=tostring(gov.meta.fallbackNoVoteHours or 48).." heures"},
        {label="Echec du quorum",text=gs.failed_quorum_rule or ""},
        {label="Revocation",text=gs.dismissal or ""},
        {label="Audit",text=gs.audit or ""}
      })
    elseif p.id=="ministries" then
      local rows=gov.ministries or {}
      local list={}
      for _,m in ipairs(rows) do list[#list+1]={text=m.code.." "..m.name.." / "..(m.holderIdentity or "VACANT"),ministry=m} end
      local x=menu("MINISTERES",list,#rows.." ministeres")
      if x then ministryDetails(x.ministry.code) end
    elseif p.id=="clients" then
      local cl=chooseClient("TERMINAUX / FONCTIONS")
      if cl then
        local role=menu("ROLE NATIONAL",{
          {text="Citoyen",v="citizen"},{text="Conseil de la Coalition",v="council"},
          {text="Justice",v="judge"},{text="Police / securite",v="police"},
          {text="Administration",v="civil_servant"},{text="Retirer l'acces national",v=""}
        },"Actuel: "..roleLabel(cl.nationalRole))
        if role then
          local id=prompt("Identite officielle",cl.nationalIdentity or cl.label)
          local out,e=rpc("NC_CLIENT_SET_ROLE",{clientId=cl.clientId,nationalRole=role.v,identity=id})
          message("TERMINAL",out and "Fonction mise a jour." or e,out and palette.accent or palette.bad)
        end
      end
    elseif p.id=="elections" then
      C.electionsScreen()
    elseif p.id=="closefounding" then
      local x=menu("CLOTURER LA PHASE FONDATRICE",{
        {text="Confirmer: appliquer les delais et regles ordinaires",id="yes"},{text="Annuler",id="no"}
      },"Apres cloture, une nomination directe exige 48h sans vote ou deux scrutins echoues.")
      if x and x.id=="yes" then
        local out,e=rpc("NC_FOUNDING_CLOSE",{})
        message("PHASE FONDATRICE",out and ("Cloturee / sceau "..tostring(out.seal)) or e,out and palette.accent or palette.bad)
      end
    end
  end
end

function C.electionDetails(id)
  while true do
    local e,err=rpc("NC_ELECTION_GET",{id=id})
    if not e then message("SCRUTIN",err,palette.bad);return end
    local info=rpc("NC_INFO",{}) or {}
    local canPresident=(info.nationalRole=="admin" or info.nationalRole=="president")
    local actions={{text="Lire le scrutin",id="read"},{text="Imprimer le scrutin",id="print"}}
    if e.stage=="draft" and canPresident then
      actions[#actions+1]={text="Ajouter un candidat",id="candidate"}
      actions[#actions+1]={text="Ouvrir le vote",id="open"}
    elseif e.stage=="open" then
      actions[#actions+1]={text="Voter",id="vote"}
      if canPresident then actions[#actions+1]={text="Clore / depouiller",id="close"} end
    end
    local a=menu(e.id.." - "..e.title,actions,e.ministryCode.." / "..e.electorate.." / "..e.stage)
    if not a then return end
    if a.id=="read" then
      local cand={}
      for _,x in ipairs(e.candidates or {}) do
        local count=e.tally and e.tally.counts and e.tally.counts[x.clientId] or 0
        cand[#cand+1]=(x.identity or x.clientId).." = "..tostring(count)
      end
      textPage(e.id,{
        {label="Ministere",text=e.ministryCode or ""},
        {label="Electorat",text=e.electorate or ""},
        {label="Statut",text=e.stage or ""},
        {label="Candidats / voix",text=table.concat(cand,"\n")},
        {label="Participation",text=e.tally and (tostring(e.tally.participation).."/"..tostring(e.tally.eligible).." / quorum "..tostring(e.tally.quorumRequired)) or "-"},
        {label="Resultat",text=(e.result or "-").." / "..(e.winnerIdentity or "-")},
        {label="Sceaux",text=(e.openSeal or "-").."\n"..(e.resultSeal or "-").."\n"..(e.appointmentSeal or "-")}
      })
    elseif a.id=="print" then
      local ok,pages=printer.election(e);message("IMPRESSION",ok and ("Scrutin imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="candidate" then
      local cl=chooseClient("CHOISIR UN CANDIDAT",function(x) return x.nationalRole~="president" and not x.ministryCode end)
      if cl then
        local out,er=rpc("NC_ELECTION_ADD_CANDIDATE",{id=e.id,clientId=cl.clientId})
        message("CANDIDATURE",out and "Candidat enregistre." or er,out and palette.accent or palette.bad)
      end
    elseif a.id=="open" then
      local out,er=rpc("NC_ELECTION_OPEN",{id=e.id})
      message("SCRUTIN",out and "Vote officiellement ouvert." or er,out and palette.accent or palette.bad)
    elseif a.id=="vote" then
      local opts={{text="ABSTENTION",choice="abstain"}}
      for _,x in ipairs(e.candidates or {}) do opts[#opts+1]={text=x.identity or x.clientId,choice=x.clientId} end
      local v=menu("VOTE MINISTERIEL",opts,"Une voix par identite nationale.")
      if v then
        local out,er=rpc("NC_ELECTION_VOTE",{id=e.id,choice=v.choice})
        message("VOTE",out and "Vote enregistre." or er,out and palette.accent or palette.bad)
      end
    elseif a.id=="close" then
      local out,er=rpc("NC_ELECTION_CLOSE",{id=e.id})
      if out then
        local x=out.election
        message("RESULTAT",x.result=="elected" and ("ELU ET NOMME: "..tostring(x.winnerIdentity)) or ("SCRUTIN ECHOUE: "..tostring(x.result)),
          x.result=="elected" and palette.accent or palette.warn)
      else message("RESULTAT",er,palette.bad) end
    end
  end
end

function C.electionsScreen()
  while true do
    local rows,err=rpc("NC_ELECTION_LIST",{})
    if not rows then message("SCRUTINS",err,palette.bad);return end
    local info=rpc("NC_INFO",{}) or {}
    local items={}
    if info.nationalRole=="admin" or info.nationalRole=="president" then
      items[#items+1]={text="[+] Ouvrir une procedure ministerielle",id="new"}
    end
    for _,e in ipairs(rows) do items[#items+1]={text=e.id.." "..e.ministryCode.." ["..e.stage.."] "..e.title,election=e} end
    local p=menu("SCRUTINS MINISTERIELS",items,#rows.." scrutin(s)")
    if not p then return end
    if p.id=="new" then
      local ministries=rpc("NC_MINISTRY_LIST",{}) or {}
      local opts={}
      for _,m in ipairs(ministries) do if not m.holderClientId then opts[#opts+1]={text=m.code.." "..m.name,ministry=m} end end
      local m=menu("MINISTERE VACANT",opts,#opts.." portefeuille(s)")
      if m then
        local electorate=menu("CORPS ELECTORAL",{{text="Conseil de la Coalition",v="council"},{text="Vote citoyen",v="citizen"}})
        local title=prompt("Titre du scrutin","Election - "..m.ministry.name)
        local out,e=rpc("NC_ELECTION_CREATE",{ministryCode=m.ministry.code,electorate=electorate and electorate.v or "council",title=title})
        message("SCRUTIN",out and ("Cree: "..out.id) or e,out and palette.accent or palette.bad)
      end
    elseif p.election then C.electionDetails(p.election.id) end
  end
end

local function billDetails(id)
  while true do
    local b,err=rpc("NC_BILL_GET",{id=id})
    if not b then message("PROJET DE LOI",err,palette.bad);return end
    local info=rpc("NC_INFO",{}) or {}
    local canCouncil=(info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="council")
    local canPresident=(info.nationalRole=="admin" or info.nationalRole=="president")
    local actions={{text="Lire le projet",id="read"},{text="Imprimer",id="print"}}
    if (b.stage=="draft" or b.stage=="debate" or b.stage=="no_quorum") and canCouncil then actions[#actions+1]={text="Ouvrir le vote",id="open"} end
    if b.stage=="voting" then
      actions[#actions+1]={text="Voter",id="vote"}
      if canCouncil then actions[#actions+1]={text="Clore le vote",id="close"} end
    end
    if b.stage=="adopted" and canPresident then actions[#actions+1]={text="Promulguer",id="enact"} end
    local a=menu(b.id.." - "..b.title,actions,b.proposalType.." / "..b.stage.." / "..b.electorate)
    if not a then return end
    if a.id=="read" then
      textPage(b.id,{
        {label="Projet",text=b.title or ""},
        {label="Type / statut",text=(b.proposalType or "").." / "..(b.stage or "")},
        {label="Resume",text=b.summary or ""},
        {label="Article cible",text=b.targetRef or "-"},
        {label="Lot",text=table.concat(b.targetRefs or {},", ")},
        {label="Categorie",text=b.categoryCode or b.proposedCategoryCode or "-"},
        {label="Titre propose",text=b.proposedTitle or "-"},
        {label="Texte propose",text=b.proposedText or "-"},
        {label="Scrutin",text=b.tally and ("Pour "..b.tally.yes.." / Contre "..b.tally.no.." / Abst "..b.tally.abstain.." / "..b.tally.participation.."/"..b.tally.eligible) or "-"},
        {label="Resultat / sceaux",text=(b.result or "-").."\n"..(b.resultSeal or "-").."\n"..(b.enactmentSeal or "-")}
      })
    elseif a.id=="print" then
      local ok,pages=printer.bill(b);message("IMPRESSION",ok and ("Projet imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="open" then
      local out,e=rpc("NC_BILL_OPEN",{id=b.id});message("VOTE",out and "Vote ouvert." or e,out and palette.accent or palette.bad)
    elseif a.id=="vote" then
      local v=menu("VOTE",{{text="POUR",v="yes"},{text="CONTRE",v="no"},{text="ABSTENTION",v="abstain"}})
      if v then
        local out,e=rpc("NC_BILL_VOTE",{id=b.id,choice=v.v});message("VOTE",out and "Vote enregistre." or e,out and palette.accent or palette.bad)
      end
    elseif a.id=="close" then
      local out,e=rpc("NC_BILL_CLOSE",{id=b.id})
      message("RESULTAT",out and string.upper(out.result or "") or e,out and (out.result=="adopted" and palette.accent or palette.warn) or palette.bad)
    elseif a.id=="enact" then
      local out,e=rpc("NC_BILL_ENACT",{id=b.id});message("PROMULGATION",out and ("Promulgue / "..tostring(out.enactmentSeal)) or e,out and palette.accent or palette.bad)
    end
  end
end

local function createBill()
  local typ=menu("TYPE DE PROJET",{
    {text="Amender un article",v="amendment"},
    {text="Abroger un article",v="repeal"},
    {text="Ratifier toute une categorie",v="ratification_bundle"},
    {text="Creer un nouvel article",v="new_law"}
  })
  if not typ then return end
  local title=prompt("Titre du projet")
  local summary=multi("EXPOSE DES MOTIFS","")
  local electorate=menu("CORPS ELECTORAL",{{text="Conseil de la Coalition",v="council"},{text="Referendum citoyen",v="citizen"}})
  local threshold=menu("MAJORITE",{
    {text="Majorite simple des suffrages exprimes",v="simple_cast"},
    {text="Majorite absolue des inscrits",v="absolute_members"},
    {text="Deux tiers des suffrages exprimes",v="two_thirds_cast"}
  })
  local payload={
    title=title,summary=summary,proposalType=typ.v,
    electorate=electorate and electorate.v or "council",
    threshold=threshold and threshold.v or "simple_cast"
  }

  if typ.v=="amendment" or typ.v=="repeal" then
    local law=chooseLaw("")
    if not law then return end
    payload.targetRef=law.id
    if typ.v=="amendment" then
      local full=rpc("NC_LAW_GET",{ref=law.id})
      payload.proposedTitle=prompt("Titre de l'article",full.title)
      payload.proposedText=multi("NOUVEAU TEXTE",full.text)
    end
  elseif typ.v=="ratification_bundle" then
    local cats=rpc("NC_CATEGORY_LIST",{}) or {}
    local items={}
    for _,cat in ipairs(cats) do items[#items+1]={text=cat.code.." "..cat.name,cat=cat} end
    local x=menu("CATEGORIE A RATIFIER",items,#items.." categories")
    if not x then return end
    payload.categoryCode=x.cat.code
  elseif typ.v=="new_law" then
    local cats=rpc("NC_CATEGORY_LIST",{}) or {}
    local items={}
    for _,cat in ipairs(cats) do items[#items+1]={text=cat.code.." "..cat.name,cat=cat} end
    local x=menu("CATEGORIE",items,#items.." categories")
    if not x then return end
    payload.proposedCategoryCode=x.cat.code
    payload.proposedTitle=prompt("Titre du nouvel article")
    payload.proposedTitleGroup=prompt("Titre / section")
    payload.proposedChapter=prompt("Chapitre")
    payload.proposedKind=prompt("Nature juridique","legislatif")
    payload.proposedMinistry=prompt("Ministere responsable")
    payload.proposedText=multi("TEXTE DU NOUVEL ARTICLE","")
  end

  local out,e=rpc("NC_BILL_CREATE",payload)
  message("PROJET DE LOI",out and ("Depose: "..out.id) or e,out and palette.accent or palette.bad)
end

local function billsScreen()
  while true do
    local rows,err=rpc("NC_BILL_LIST",{})
    if not rows then message("LEGISLATION",err,palette.bad);return end
    local info=rpc("NC_INFO",{}) or {}
    local items={}
    if info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="council" or info.nationalRole=="minister" then
      items[#items+1]={text="[+] Deposer un projet de loi",id="new"}
    end
    for _,b in ipairs(rows) do items[#items+1]={text=b.id.." ["..b.stage.."] "..b.title,bill=b} end
    local p=menu("LEGISLATION NATIONALE",items,#rows.." projet(s)")
    if not p then return end
    if p.id=="new" then createBill() elseif p.bill then billDetails(p.bill.id) end
  end
end

local function decreeDetails(id)
  while true do
    local d,err=rpc("NC_DECREE_GET",{id=id})
    if not d then message("DECRET",err,palette.bad);return end
    local actions={{text="Lire le decret",id="read"},{text="Imprimer",id="print"}}
    if d.status=="draft" then actions[#actions+1]={text="Publier",id="publish"}
    elseif d.status=="published" then actions[#actions+1]={text="Abroger",id="repeal"} end
    local a=menu(d.id.." - "..d.title,actions,d.scope.." / "..d.status)
    if not a then return end
    if a.id=="read" then
      textPage(d.id,{
        {label="Titre",text=d.title or ""},{label="Portee",text=(d.scope or "").." / "..(d.ministryCode or "-")},
        {label="Base legale",text=d.legalBasis or "-"},{label="Statut",text=d.status or ""},
        {label="Texte",text=d.body or ""},{label="Auteur",text=d.createdBy or ""},
        {label="Publication",text=(d.publishedAt or "-").." / "..(d.publishedBy or "-")},
        {label="Sceau",text=d.seal or "-"},{label="Abrogation",text=d.repealReason or "-"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.decree(d);message("IMPRESSION",ok and ("Decret imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="publish" then
      local out,e=rpc("NC_DECREE_PUBLISH",{id=d.id});message("DECRET",out and ("Publie / "..tostring(out.seal)) or e,out and palette.accent or palette.bad)
    elseif a.id=="repeal" then
      local reason=multi("MOTIF D'ABROGATION","")
      local out,e=rpc("NC_DECREE_REPEAL",{id=d.id,reason=reason});message("DECRET",out and "Decret abroge." or e,out and palette.accent or palette.bad)
    end
  end
end

local function decreesScreen(info)
  while true do
    local rows,err=rpc("NC_DECREE_LIST",{})
    if not rows then message("DECRETS",err,palette.bad);return end
    local items={}
    if info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="minister" then
      items[#items+1]={text="[+] Rediger un decret",id="new"}
    end
    for _,d in ipairs(rows) do items[#items+1]={text=d.id.." ["..d.status.."] "..d.title.." / "..(d.ministryCode~="" and d.ministryCode or "NATIONAL"),decree=d} end
    local p=menu("DECRETS ET REGLEMENTS",items,#rows.." decret(s)")
    if not p then return end
    if p.id=="new" then
      local scope=info.nationalRole=="minister" and "ministry" or (menu("PORTEE",{{text="Decret national",v="national"},{text="Decret ministeriel",v="ministry"}}) or {}).v
      if not scope then return end
      local ministryCode=info.nationalRole=="minister" and info.ministryCode or ""
      if scope=="ministry" and ministryCode=="" then
        local ms=rpc("NC_MINISTRY_LIST",{}) or {}
        local opts={};for _,m in ipairs(ms) do opts[#opts+1]={text=m.code.." "..m.name,m=m} end
        local x=menu("MINISTERE",opts);if not x then return end;ministryCode=x.m.code
      end
      local title=prompt("Titre du decret")
      local legalBasis=prompt("Base legale NC-ART-... (optionnel)")
      local body=multi("TEXTE DU DECRET","")
      local out,e=rpc("NC_DECREE_CREATE",{scope=scope,ministryCode=ministryCode,title=title,legalBasis=legalBasis,body=body})
      message("DECRET",out and ("Brouillon cree: "..out.id) or e,out and palette.accent or palette.bad)
    elseif p.decree then decreeDetails(p.decree.id) end
  end
end

local function auditScreen()
  local rows,err=rpc("NC_AUDIT_LIST",{limit=150})
  if not rows then message("AUDIT NATIONAL",err,palette.bad);return end
  local lines={}
  for _,r in ipairs(rows) do lines[#lines+1]=(r.at or "").." / "..(r.actor or "").." / "..(r.action or "").." / "..(r.objectId or "").."\n"..(r.details or "") end
  textPage("JOURNAL NATIONAL",{{label="Dernieres operations",text=table.concat(lines,"\n\n")}})
end

function C.run()
  cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  common.openModems()

  local info,err=rpc("NC_INFO",{})
  if not info then
    if cfg.role=="admin" then
      local x=menu("INTRANET NORTH COALITION",{
        {text="Initialiser ce terminal comme Presidence NexoFr_",id="bootstrap"},
        {text="Retour",id="back"}
      },"L'intranet national n'est pas encore initialise pour ce terminal.")
      if x and x.id=="bootstrap" then
        local out,e=rpc("NC_BOOTSTRAP",{})
        if not out then message("INITIALISATION",e,palette.bad);return end
        info=rpc("NC_INFO",{})
      else return end
    else
      message("ACCES NATIONAL",err or "Terminal non autorise.",palette.bad)
      return
    end
  elseif cfg.role=="admin" and not info.presidentClientId then
    local x=menu("INITIALISATION NATIONALE",{
      {text="Enregistrer ce terminal comme Presidence NexoFr_",id="bootstrap"},
      {text="Continuer uniquement en administrateur",id="admin"}
    },"Le corpus est installe mais aucun terminal presidentiel n'est encore enregistre.")
    if x and x.id=="bootstrap" then
      local out,e=rpc("NC_BOOTSTRAP",{})
      if not out then message("INITIALISATION",e,palette.bad);return end
      info=rpc("NC_INFO",{}) or info
    end
  end

  while true do
    local dash,e=rpc("NC_DASHBOARD",{})
    if not dash then message("INTRANET NATIONAL",e,palette.bad);return end
    info=rpc("NC_INFO",{}) or info
    local subtitle=roleLabel(dash.nationalRole).." / "..tostring(dash.nationalIdentity)..
      (dash.ministryCode and (" / "..dash.ministryCode) or "")..
      " | "..dash.activeLaws.." lois actives / "..dash.openElections.." scrutin(s)"

    local items={
      {text="CODE NATIONAL / CATEGORIES / RECHERCHE",id="code"},
      {text="GOUVERNEMENT / MINISTERES / FONCTIONS",id="gov"},
      {text="LEGISLATION / PROJETS / VOTES",id="bills"},
      {text="ELECTIONS MINISTERIELLES",id="elections"},
      {text="DECRETS / REGLEMENTS",id="decrees"}
    }
    if dash.nationalRole=="admin" or dash.nationalRole=="president" or dash.nationalRole=="council" or dash.nationalRole=="judge" then
      items[#items+1]={text="JOURNAL D'AUDIT NATIONAL",id="audit"}
    end
    items[#items+1]={text="RETOUR AU SYSTEME INTERNATIONAL",id="back"}

    local p=menu("INTRANET NATIONAL",items,subtitle)
    if not p or p.id=="back" then clear();return end
    if p.id=="code" then codeScreen()
    elseif p.id=="gov" then governmentScreen(info)
    elseif p.id=="bills" then billsScreen()
    elseif p.id=="elections" then C.electionsScreen()
    elseif p.id=="decrees" then decreesScreen(info)
    elseif p.id=="audit" then auditScreen() end
  end
end

return C
