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

-- Forward declarations: the draft editor can open the legal browser without
-- destroying the text currently being written.
local chooseLaw
local lawDetails

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
    footer("E=editer  C=consulter le Code  F=finir  A=annuler")
    local ev,key=os.pullEvent("key")
    if key==keys.e then
      shell.run("edit",path)
    elseif key==keys.c then
      -- The editor file stays untouched while the user browses/searches the
      -- national code, then we return to the same draft preview.
      if chooseLaw then
        local picked=chooseLaw("")
        if picked and lawDetails then lawDetails(picked.id) end
      end
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
    minister="Ministre",judge="Juge",prosecutor="Parquet / Procureur",police="Police / securite",civil_servant="Administration",
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

lawDetails=function(ref)
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

chooseLaw=function(query)
  local function pickRows(rows,title,subtitle)
    if not rows or #rows==0 then
      message(title or "CODE","Aucun article correspondant.",palette.muted)
      return nil
    end
    local items={}
    for _,law in ipairs(rows) do
      items[#items+1]={
        text=(law.display_reference or law.id).." "..law.title.." / "..(law.category_code or "").." ["..(law.status or "?").."]",
        law=law
      }
    end
    local p=menu(title or "CHOISIR UN ARTICLE",items,subtitle or (#rows.." resultat(s)"))
    return p and p.law or nil
  end

  local function browseCategory()
    local cats,err=rpc("NC_CATEGORY_LIST",{})
    if not cats then message("CODE",err,palette.bad);return nil end
    local catItems={}
    for _,cat in ipairs(cats) do
      local counts=cat.counts or {}
      catItems[#catItems+1]={
        text=cat.code.." "..cat.name.." ("..tostring(counts.total or 0)..")",cat=cat
      }
    end
    local pickedCat=menu("PARCOURIR PAR CATEGORIE",catItems,#catItems.." categorie(s)")
    if not pickedCat then return nil end

    local rows,lawErr=rpc("NC_LAW_LIST",{category_code=pickedCat.cat.code})
    if not rows then message("CODE",lawErr,palette.bad);return nil end

    local titleMap={}
    for _,law in ipairs(rows) do
      local titleKey=(law.title_code or "").."|"..(law.title_group or "Sans titre")
      local title=titleMap[titleKey]
      if not title then
        title={code=law.title_code or "",name=law.title_group or "Sans titre",chapters={}}
        titleMap[titleKey]=title
      end
      local chapterKey=(law.chapter_code or "").."|"..(law.chapter or "Sans chapitre")
      local chapter=title.chapters[chapterKey]
      if not chapter then
        chapter={code=law.chapter_code or "",name=law.chapter or "Sans chapitre",laws={}}
        title.chapters[chapterKey]=chapter
      end
      chapter.laws[#chapter.laws+1]=law
    end

    local titles={}
    for _,title in pairs(titleMap) do titles[#titles+1]=title end
    table.sort(titles,function(a,b) return tostring(a.code)<tostring(b.code) end)
    local titleItems={}
    for _,title in ipairs(titles) do
      local count=0
      for _,chapter in pairs(title.chapters) do count=count+#chapter.laws end
      titleItems[#titleItems+1]={text=(title.code~="" and (title.code.." / ") or "")..title.name.." ("..count..")",title=title}
    end
    local pickedTitle=menu(pickedCat.cat.code.." / TITRES",titleItems,#rows.." article(s)")
    if not pickedTitle then return nil end

    local chapters={}
    for _,chapter in pairs(pickedTitle.title.chapters) do chapters[#chapters+1]=chapter end
    table.sort(chapters,function(a,b) return tostring(a.code)<tostring(b.code) end)
    local chapterItems={}
    for _,chapter in ipairs(chapters) do
      chapterItems[#chapterItems+1]={
        text=(chapter.code~="" and (chapter.code.." / ") or "")..chapter.name.." ("..#chapter.laws..")",chapter=chapter
      }
    end
    local pickedChapter=menu((pickedTitle.title.code or "").." / CHAPITRES",chapterItems,"Choisissez un chapitre")
    if not pickedChapter then return nil end

    table.sort(pickedChapter.chapter.laws,function(a,b) return (a.number or 0)<(b.number or 0) end)
    return pickRows(pickedChapter.chapter.laws,
      (pickedChapter.chapter.code or "").." / ARTICLES",
      pickedCat.cat.name.." / "..pickedTitle.title.name)
  end

  query=common.trim(query or "")
  if query~="" then
    local rows,err=rpc("NC_LAW_LIST",{query=query})
    if not rows then message("CODE",err,palette.bad);return nil end
    return pickRows(rows,"RESULTATS DE RECHERCHE",#rows.." resultat(s) pour \""..query.."\"")
  end

  while true do
    local mode=menu("CHOISIR UN ARTICLE",{
      {text="[?] Rechercher par numero, titre ou mot",id="search"},
      {text="[C] Parcourir categorie > titre > chapitre",id="category"},
      {text="[#] Ouvrir directement NC-ART-...",id="direct"}
    },"Le Code reste accessible sans fermer votre brouillon.")
    if not mode then return nil end

    if mode.id=="search" then
      local q=prompt("Numero, titre, mot, chapitre, ministere")
      if q~="" then
        local rows,err=rpc("NC_LAW_LIST",{query=q})
        if not rows then message("CODE",err,palette.bad)
        else
          local law=pickRows(rows,"RESULTATS DE RECHERCHE",#rows.." resultat(s)")
          if law then return law end
        end
      end
    elseif mode.id=="category" then
      local law=browseCategory()
      if law then return law end
    elseif mode.id=="direct" then
      local ref=prompt("Reference","NC-ART-001")
      if ref~="" then
        local law,err=rpc("NC_LAW_GET",{ref=ref})
        if law then return law else message("ARTICLE",err,palette.bad) end
      end
    end
  end
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
      items[#items+1]={text=(cl.nationalIdentity or cl.label).." / "..(cl.citizenId or "sans NC-CIT").." / PC #"..tostring(cl.computerId).." / "..roleLabel(cl.nationalRole),client=cl}
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
      local cl=chooseClient("CHOISIR LE MINISTRE",function(x) return x.citizenId and x.nationalRole~="president" and not x.ministryCode end)
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
          {text="Juge",v="judge"},{text="Parquet / Procureur",v="prosecutor"},
          {text="Police / securite",v="police"},
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
      local cl=chooseClient("CHOISIR UN CANDIDAT",function(x) return x.citizenId and x.nationalRole~="president" and not x.ministryCode end)
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



local function caseTypeLabel(v)
  local labels={
    criminal="Penal",civil="Civil",administrative="Administratif",constitutional="Constitutionnel"
  }
  return labels[v] or tostring(v or "")
end

local function caseStatusMenu(current)
  local options={
    open={{text="Enquete",v="investigation"},{text="Audience",v="hearing"},{text="Clore",v="closed"}},
    investigation={{text="Audience",v="hearing"},{text="Clore",v="closed"}},
    hearing={{text="Juge",v="judged"},{text="Clore",v="closed"}},
    judged={{text="Appel",v="appeal"},{text="Clore",v="closed"}},
    appeal={{text="Retour a juge",v="judged"},{text="Clore",v="closed"}},
    closed={{text="Archiver",v="archived"}}
  }
  local rows=options[current] or {}
  return menu("NOUVEAU STATUT",rows,"Actuel: "..tostring(current))
end

local function caseDetails(id)
  while true do
    local case,err=rpc("NC_CASE_GET",{id=id})
    if not case then message("DOSSIER NATIONAL",err,palette.bad);return end
    local info=rpc("NC_INFO",{}) or {}
    local role=info.nationalRole
    local investigator=(role=="admin" or role=="judge" or role=="prosecutor" or role=="police")
    local judicial=(role=="admin" or role=="judge")
    local prosecutor=(role=="admin" or role=="judge" or role=="prosecutor")

    local actions={
      {text="Lire le dossier complet",id="read"},
      {text="Imprimer le dossier",id="print"},
      {text="Articles nationaux cites ("..tostring(#(case.citedArticles or {}))..")",id="articles"},
      {text="Audiences ("..tostring(#(case.hearings or {}))..")",id="hearings"},
      {text="Ordonnances ("..tostring(#(case.orders or {}))..")",id="orders"},
      {text="Jugements ("..tostring(#(case.judgments or {}))..")",id="judgments"},
      {text="Appels ("..tostring(#(case.appeals or {}))..")",id="appeals"}
    }
    if investigator then
      actions[#actions+1]={text="[+] Ajouter un fait",id="fact"}
      actions[#actions+1]={text="[+] Ajouter une preuve",id="evidence"}
      actions[#actions+1]={text="[+] Citer un article national",id="cite"}
    end
    if prosecutor then actions[#actions+1]={text="Changer le statut procedural",id="status"} end
    if role=="police" and case.status=="open" then actions[#actions+1]={text="Passer en enquete",id="investigate"} end
    if judicial then
      actions[#actions+1]={text="[+] Planifier une audience",id="hearing_new"}
      actions[#actions+1]={text="[+] Emettre une ordonnance",id="order_new"}
      actions[#actions+1]={text="[+] Rendre un jugement",id="judgment_new"}
      actions[#actions+1]={text="Modifier la visibilite",id="visibility"}
    end
    if case.status=="judged" or case.status=="closed" then actions[#actions+1]={text="Former appel",id="appeal_new"} end

    local a=menu(case.id.." - "..case.title,actions,
      caseTypeLabel(case.caseType).." / "..case.status.." / "..case.visibility)
    if not a then return end

    if a.id=="read" then
      local facts={}
      for _,x in ipairs(case.facts or {}) do facts[#facts+1]=(x.id or "?").." / "..(x.text or "").." / "..(x.by or "").."\nSceau: "..(x.seal or "-") end
      local evidence={}
      for _,x in ipairs(case.evidence or {}) do evidence[#evidence+1]=(x.id or "?").." / "..(x.label or "").."\n"..(x.description or "").."\nSource: "..(x.source or "-").."\nSceau: "..(x.seal or "-") end
      local hearings={}
      for _,x in ipairs(case.hearings or {}) do hearings[#hearings+1]=(x.id or "?").." ["..(x.status or "?").."] "..(x.scheduledFor or "").." / "..(x.subject or "")..(x.recordSeal and ("\nPV: "..x.recordSeal) or "") end
      local orders={}
      for _,x in ipairs(case.orders or {}) do orders[#orders+1]=(x.id or "?").." ["..(x.status or "?").."] "..(x.orderType or "").." / "..(x.subject or "").."\nSceau: "..(x.seal or "-") end
      local judgments={}
      for _,x in ipairs(case.judgments or {}) do judgments[#judgments+1]=(x.id or "?").." / "..(x.date or "").." / "..(x.judge or "").."\n"..(x.verdict or "").."\nSceau: "..(x.seal or "-") end
      local appeals={}
      for _,x in ipairs(case.appeals or {}) do appeals[#appeals+1]=(x.id or "?").." ["..(x.status or "?").."] "..(x.appellant or "")..(x.result and (" / "..x.result) or "") end
      local timeline={}
      for _,x in ipairs(case.timeline or {}) do timeline[#timeline+1]=(x.at or "").." / "..(x.title or x.kind or "").."\n"..(x.details or "") end

      textPage(case.id,{
        {label="Titre",text=case.title or ""},
        {label="Type / statut",text=caseTypeLabel(case.caseType).." / "..(case.status or "")},
        {label="Visibilite",text=case.visibility or ""},
        {label="Demandeur",text=case.complainant or "-"},
        {label="Mis en cause",text=case.accused or "-"},
        {label="Resume",text=case.summary or ""},
        {label="Sceau initial",text=case.seal or "-"},
        {label="Faits",text=#facts>0 and table.concat(facts,"\n\n") or "Aucun"},
        {label="Preuves",text=#evidence>0 and table.concat(evidence,"\n\n") or "Aucune"},
        {label="Articles cites",text=#(case.citedArticles or {})>0 and table.concat(case.citedArticles,"\n") or "Aucun"},
        {label="Audiences",text=#hearings>0 and table.concat(hearings,"\n\n") or "Aucune"},
        {label="Ordonnances",text=#orders>0 and table.concat(orders,"\n\n") or "Aucune"},
        {label="Jugements",text=#judgments>0 and table.concat(judgments,"\n\n") or "Aucun"},
        {label="Appels",text=#appeals>0 and table.concat(appeals,"\n\n") or "Aucun"},
        {label="Chronologie",text=#timeline>0 and table.concat(timeline,"\n\n") or "Aucune"}
      })

    elseif a.id=="print" then
      local ok,pages=printer.caseFile(case)
      message("IMPRESSION",ok and ("Dossier imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)

    elseif a.id=="fact" then
      local text=multi("FAIT / CONSTAT","")
      local out,e=rpc("NC_CASE_ADD_FACT",{id=case.id,text=text})
      message("FAIT",out and "Fait ajoute et scelle." or e,out and palette.accent or palette.bad)

    elseif a.id=="evidence" then
      local label=prompt("Nom / reference de la preuve")
      local source=prompt("Source / origine")
      local description=multi("DESCRIPTION DE LA PREUVE","")
      local out,e=rpc("NC_CASE_ADD_EVIDENCE",{id=case.id,label=label,source=source,description=description})
      message("PREUVE",out and "Preuve ajoutee et scellee." or e,out and palette.accent or palette.bad)

    elseif a.id=="cite" then
      local law=chooseLaw("")
      if law then
        local out,e=rpc("NC_CASE_ADD_ARTICLE",{id=case.id,ref=law.id})
        message("ARTICLE",out and ((law.display_reference or law.id).." ajoute au dossier.") or e,out and palette.accent or palette.bad)
      end

    elseif a.id=="articles" then
      local items={}
      for _,ref in ipairs(case.citedArticles or {}) do
        local law=rpc("NC_LAW_GET",{ref=ref})
        items[#items+1]={text=law and ((law.display_reference or law.id).." "..law.title) or ref,ref=ref,law=law}
      end
      if #items==0 then message("ARTICLES","Aucun article cite.",palette.muted)
      else
        local x=menu("ARTICLES CITES",items,#items.." article(s)")
        if x then
          local op={{text="Lire l'article",id="read"}}
          if investigator then op[#op+1]={text="Retirer cette citation",id="remove"} end
          local y=menu(x.ref,op)
          if y and y.id=="read" then lawDetails(x.ref)
          elseif y and y.id=="remove" then
            local out,e=rpc("NC_CASE_REMOVE_ARTICLE",{id=case.id,ref=x.ref})
            message("ARTICLE",out and "Citation retiree." or e,out and palette.accent or palette.bad)
          end
        end
      end

    elseif a.id=="status" then
      local st=caseStatusMenu(case.status)
      if st then
        local reason=prompt("Motif / note")
        local out,e=rpc("NC_CASE_SET_STATUS",{id=case.id,status=st.v,reason=reason})
        message("PROCEDURE",out and ("Statut: "..out.status) or e,out and palette.accent or palette.bad)
      end

    elseif a.id=="investigate" then
      local out,e=rpc("NC_CASE_SET_STATUS",{id=case.id,status="investigation",reason="Ouverture de l'enquete"})
      message("PROCEDURE",out and "Dossier passe en enquete." or e,out and palette.accent or palette.bad)

    elseif a.id=="visibility" then
      local v=menu("VISIBILITE DU DOSSIER",{
        {text="Public",v="public"},{text="Restreint",v="restricted"},{text="Scelle",v="sealed"}
      },"Actuel: "..case.visibility)
      if v then
        local out,e=rpc("NC_CASE_SET_VISIBILITY",{id=case.id,visibility=v.v})
        message("VISIBILITE",out and ("Niveau: "..out.visibility) or e,out and palette.accent or palette.bad)
      end

    elseif a.id=="hearing_new" then
      local subject=prompt("Objet de l'audience")
      local scheduledFor=prompt("Date / heure RP")
      local location=prompt("Salle / lieu")
      local out,e=rpc("NC_CASE_ADD_HEARING",{id=case.id,subject=subject,scheduledFor=scheduledFor,location=location})
      message("AUDIENCE",out and "Audience planifiee." or e,out and palette.accent or palette.bad)

    elseif a.id=="hearings" then
      local items={}
      for _,h in ipairs(case.hearings or {}) do items[#items+1]={text=(h.id or "?").." ["..(h.status or "?").."] "..(h.scheduledFor or "").." "..(h.subject or ""),hearing=h} end
      if #items==0 then message("AUDIENCES","Aucune audience.",palette.muted)
      else
        local x=menu("AUDIENCES",items,#items.." audience(s)")
        if x then
          local h=x.hearing
          local ops={{text="Lire la fiche",id="read"}}
          if judicial and h.status=="scheduled" then ops[#ops+1]={text="Enregistrer le proces-verbal",id="record"} end
          local y=menu(h.id,ops,h.subject)
          if y and y.id=="read" then
            textPage(h.id,{
              {label="Objet",text=h.subject or ""},{label="Date",text=h.scheduledFor or ""},
              {label="Lieu",text=h.location or ""},{label="Statut",text=h.status or ""},
              {label="Proces-verbal",text=h.minutes or "-"},{label="Sceaux",text=(h.seal or "-").."\n"..(h.recordSeal or "-")}
            })
          elseif y and y.id=="record" then
            local minutes=multi("PROCES-VERBAL D'AUDIENCE","")
            local st=menu("ISSUE",{{text="Audience terminee",v="completed"},{text="Audience annulee",v="cancelled"}})
            local out,e=rpc("NC_CASE_RECORD_HEARING",{id=case.id,hearingId=h.id,minutes=minutes,status=st and st.v or "completed"})
            message("AUDIENCE",out and "Proces-verbal scelle." or e,out and palette.accent or palette.bad)
          end
        end
      end

    elseif a.id=="order_new" then
      local typ=menu("TYPE D'ORDONNANCE",{
        {text="Perquisition",v="search"},{text="Saisie",v="seizure"},{text="Arrestation",v="arrest"},
        {text="Mise en liberte",v="release"},{text="Protection",v="protection"},
        {text="Injonction",v="injunction"},{text="Autre",v="other"}
      })
      if typ then
        local subject=prompt("Objet / personne / lieu")
        local expiresAt=prompt("Expiration (optionnel)")
        local grounds=multi("MOTIFS JURIDIQUES","")
        local out,e=rpc("NC_CASE_ADD_ORDER",{id=case.id,orderType=typ.v,subject=subject,expiresAt=expiresAt,grounds=grounds})
        message("ORDONNANCE",out and "Ordonnance emise et scellee." or e,out and palette.accent or palette.bad)
      end

    elseif a.id=="orders" then
      local items={}
      for _,o in ipairs(case.orders or {}) do items[#items+1]={text=(o.id or "?").." ["..(o.status or "?").."] "..(o.orderType or "").." "..(o.subject or ""),order=o} end
      if #items==0 then message("ORDONNANCES","Aucune ordonnance.",palette.muted)
      else
        local x=menu("ORDONNANCES",items,#items.." ordonnance(s)")
        if x then
          local o=x.order
          local ops={{text="Lire",id="read"}}
          if judicial then ops[#ops+1]={text="Changer le statut",id="status"} end
          local y=menu(o.id,ops)
          if y and y.id=="read" then
            textPage(o.id,{
              {label="Type",text=o.orderType or ""},{label="Objet",text=o.subject or ""},
              {label="Motifs",text=o.grounds or ""},{label="Statut",text=o.status or ""},
              {label="Expiration",text=o.expiresAt or "-"},{label="Sceau",text=o.seal or "-"}
            })
          elseif y and y.id=="status" then
            local st=menu("STATUT",{{text="Active",v="active"},{text="Executee",v="executed"},{text="Revoquee",v="revoked"},{text="Expiree",v="expired"}})
            if st then
              local out,e=rpc("NC_CASE_SET_ORDER_STATUS",{id=case.id,orderId=o.id,status=st.v})
              message("ORDONNANCE",out and "Statut mis a jour." or e,out and palette.accent or palette.bad)
            end
          end
        end
      end

    elseif a.id=="judgment_new" then
      local verdict=multi("DECISION / VERDICT","")
      local reasoning=multi("MOTIVATION JURIDIQUE","")
      local sanctions=multi("SANCTIONS / REPARATIONS / MESURES","")
      local final=menu("NATURE",{{text="Jugement final",v=true},{text="Decision intermediaire",v=false}})
      local out,e=rpc("NC_CASE_ADD_JUDGMENT",{id=case.id,verdict=verdict,reasoning=reasoning,sanctions=sanctions,final=final and final.v or true})
      message("JUGEMENT",out and "Jugement enregistre et articles figes." or e,out and palette.accent or palette.bad)

    elseif a.id=="judgments" then
      local items={}
      for _,j in ipairs(case.judgments or {}) do items[#items+1]={text=(j.id or "?").." "..(j.date or "").." / "..(j.verdict or ""),judgment=j} end
      if #items==0 then message("JUGEMENTS","Aucun jugement.",palette.muted)
      else
        local x=menu("JUGEMENTS",items,#items.." decision(s)")
        if x then
          local j=x.judgment
          local y=menu(j.id,{{text="Lire la decision",id="read"},{text="Imprimer ce jugement",id="print"}})
          if y and y.id=="read" then
            local refs={}
            for _,law in ipairs(j.citedArticleVersions or {}) do refs[#refs+1]=(law.display_reference or law.id).." v"..tostring(law.version).." / "..(law.title or "") end
            textPage(j.id,{
              {label="Juge",text=j.judge or ""},{label="Date",text=j.date or ""},
              {label="Decision",text=j.verdict or ""},{label="Motivation",text=j.reasoning or ""},
              {label="Sanctions / mesures",text=j.sanctions or "-"},
              {label="Articles figes",text=#refs>0 and table.concat(refs,"\n") or "Aucun"},
              {label="Sceau",text=j.seal or "-"}
            })
          elseif y and y.id=="print" then
            local ok,pages=printer.judgment(case,j)
            message("IMPRESSION",ok and ("Jugement imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
          end
        end
      end

    elseif a.id=="appeal_new" then
      local grounds=multi("MOTIFS D'APPEL","")
      local out,e=rpc("NC_CASE_FILE_APPEAL",{id=case.id,grounds=grounds})
      message("APPEL",out and "Appel depose." or e,out and palette.accent or palette.bad)

    elseif a.id=="appeals" then
      local items={}
      for _,ap in ipairs(case.appeals or {}) do items[#items+1]={text=(ap.id or "?").." ["..(ap.status or "?").."] "..(ap.appellant or "")..(ap.result and (" / "..ap.result) or ""),appeal=ap} end
      if #items==0 then message("APPELS","Aucun appel.",palette.muted)
      else
        local x=menu("APPELS",items,#items.." appel(s)")
        if x then
          local ap=x.appeal
          local ops={{text="Lire",id="read"}}
          if judicial and ap.status=="pending" then ops[#ops+1]={text="Rendre la decision d'appel",id="decide"} end
          local y=menu(ap.id,ops)
          if y and y.id=="read" then
            textPage(ap.id,{
              {label="Appelant",text=ap.appellant or ""},{label="Motifs",text=ap.grounds or ""},
              {label="Statut",text=ap.status or ""},{label="Resultat",text=ap.result or "-"},
              {label="Motivation d'appel",text=ap.reasoning or "-"},{label="Sceaux",text=(ap.seal or "-").."\n"..(ap.decisionSeal or "-")}
            })
          elseif y and y.id=="decide" then
            local rs=menu("DECISION D'APPEL",{
              {text="Confirmer",v="upheld"},{text="Infirmer",v="reversed"},{text="Modifier",v="modified"},
              {text="Renvoyer en audience",v="remanded"},{text="Rejeter",v="dismissed"}
            })
            if rs then
              local reasoning=multi("MOTIVATION DE L'APPEL","")
              local out,e=rpc("NC_CASE_DECIDE_APPEAL",{id=case.id,appealId=ap.id,result=rs.v,reasoning=reasoning})
              message("APPEL",out and "Decision d'appel enregistree." or e,out and palette.accent or palette.bad)
            end
          end
        end
      end
    end
  end
end

local function casesScreen()
  local query,status="",""
  while true do
    local rows,err=rpc("NC_CASE_LIST",{query=query,status=status})
    if not rows then message("JUSTICE NATIONALE",err,palette.bad);return end
    local info=rpc("NC_INFO",{}) or {}
    local role=info.nationalRole
    local canCreate=(role=="admin" or role=="judge" or role=="prosecutor" or role=="police")
    local items={}
    if canCreate then items[#items+1]={text="[+] Ouvrir un dossier national",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer par statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"} end
    for _,case in ipairs(rows) do
      items[#items+1]={text=case.id.." ["..case.status.."] "..case.title.." / "..caseTypeLabel(case.caseType),case=case}
    end
    local p=menu("JUSTICE / DOSSIERS NATIONAUX",items,#rows.." dossier(s) visible(s)")
    if not p then return end

    if p.id=="new" then
      local typ=menu("TYPE DE DOSSIER",{
        {text="Penal",v="criminal"},{text="Civil",v="civil"},
        {text="Administratif",v="administrative"},{text="Constitutionnel",v="constitutional"}
      })
      if typ then
        local title=prompt("Titre du dossier")
        local complainant=prompt("Demandeur / plaignant")
        local accused=prompt("Mis en cause / defendeur")
        local visibility=menu("VISIBILITE",{
          {text="Restreinte",v="restricted"},{text="Publique",v="public"},{text="Scellee",v="sealed"}
        })
        local summary=multi("RESUME / OBJET DU DOSSIER","")
        local out,e=rpc("NC_CASE_CREATE",{
          title=title,caseType=typ.v,complainant=complainant,accused=accused,
          visibility=visibility and visibility.v or "restricted",summary=summary
        })
        message("DOSSIER",out and ("Ouvert: "..out.id) or e,out and palette.accent or palette.bad)
      end
    elseif p.id=="search" then
      query=prompt("Recherche dossier / partie",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{
        {text="Tous",v=""},{text="Ouverts",v="open"},{text="En enquete",v="investigation"},
        {text="Audience",v="hearing"},{text="Juges",v="judged"},{text="Appel",v="appeal"},
        {text="Clos",v="closed"},{text="Archives",v="archived"}
      })
      if st then status=st.v end
    elseif p.id=="reset" then query="";status=""
    elseif p.case then caseDetails(p.case.id) end
  end
end


local function citizenDetails(id,info)
  while true do
    local cit,err=rpc("NC_CITIZEN_GET",{id=id})
    if not cit then message("REGISTRE CIVIL",err,palette.bad);return end
    local canManage=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-INT"))
    local actions={{text="Lire la fiche d'identite",id="read"}}
    if canManage then
      actions[#actions+1]={text="Modifier l'identite / statut",id="edit"}
      actions[#actions+1]={text="Rattacher un terminal",id="link"}
    end
    local a=menu(cit.id.." - "..(cit.displayName or cit.identity),actions,
      (cit.status or "?").." / identite officielle "..(cit.identity or ""))
    if not a then return end

    if a.id=="read" then
      local hist={}
      for _,h in ipairs(cit.history or {}) do
        hist[#hist+1]=(h.at or "").." / "..(h.by or "")..
          " / "..tostring((h.old or {}).status or "?").." -> "..tostring((h.new or {}).status or "?")..
          "\nSceau: "..(h.seal or "-")
      end
      local linked={}
      if canManage then
        local clients=rpc("NC_CLIENT_LIST",{}) or {}
        for _,cl in ipairs(clients) do
          if cl.citizenId==cit.id then linked[#linked+1]=(cl.label or cl.clientId).." / PC #"..tostring(cl.computerId).." / "..roleLabel(cl.nationalRole) end
        end
      end
      textPage(cit.id,{
        {label="Identite officielle",text=cit.identity or ""},
        {label="Nom affiche",text=cit.displayName or ""},
        {label="Statut civil",text=cit.status or ""},
        {label="Sceau initial",text=cit.seal or "-"},
        {label="Notes administratives",text=cit.notes or (canManage and "Aucune" or "[restreintes]")},
        {label="Terminaux rattaches",text=#linked>0 and table.concat(linked,"\n") or (canManage and "Aucun" or "[reserve administration]")},
        {label="Historique",text=#hist>0 and table.concat(hist,"\n\n") or "Aucune modification"}
      })

    elseif a.id=="edit" then
      local identityValue=prompt("Identite officielle",cit.identity or "")
      local displayName=prompt("Nom affiche",cit.displayName or identityValue)
      local st=menu("STATUT CIVIL",{
        {text="Citoyen actif",v="citizen"},{text="Resident",v="resident"},
        {text="Suspendu",v="suspended"},{text="Decede / archive",v="deceased"}
      },"Actuel: "..(cit.status or ""))
      local notes=multi("NOTES ADMINISTRATIVES",cit.notes or "")
      local out,e=rpc("NC_CITIZEN_UPDATE",{
        id=cit.id,identity=identityValue,displayName=displayName,
        status=st and st.v or cit.status,notes=notes
      })
      message("REGISTRE CIVIL",out and "Identite mise a jour." or e,out and palette.accent or palette.bad)

    elseif a.id=="link" then
      local cl=chooseClient("RATTACHER UN TERMINAL")
      if cl then
        local out,e=rpc("NC_CITIZEN_LINK_CLIENT",{citizenId=cit.id,clientId=cl.clientId})
        message("REGISTRE CIVIL",out and ("Terminal rattache a "..cit.id) or e,out and palette.accent or palette.bad)
      end
    end
  end
end

local function citizensScreen(info)
  local query,status="",""
  while true do
    local rows,err=rpc("NC_CITIZEN_LIST",{query=query,status=status})
    if not rows then message("REGISTRE CIVIL",err,palette.bad);return end
    local canManage=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-INT"))
    local items={}
    if canManage then items[#items+1]={text="[+] Enregistrer une identite",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser filtres",id="reset"} end
    for _,cit in ipairs(rows) do
      items[#items+1]={text=cit.id.." ["..(cit.status or "?").."] "..(cit.displayName or cit.identity),citizen=cit}
    end

    local p=menu("REGISTRE CIVIL / CITOYENS",items,#rows.." identite(s)")
    if not p then return end
    if p.id=="new" then
      local identityValue=prompt("Identite officielle")
      local displayName=prompt("Nom affiche",identityValue)
      local st=menu("STATUT INITIAL",{
        {text="Citoyen",v="citizen"},{text="Resident",v="resident"}
      })
      local notes=multi("NOTES ADMINISTRATIVES","")
      local out,e=rpc("NC_CITIZEN_CREATE",{
        identity=identityValue,displayName=displayName,status=st and st.v or "citizen",notes=notes
      })
      message("REGISTRE CIVIL",out and ("Enregistre: "..out.id) or e,out and palette.accent or palette.bad)
    elseif p.id=="search" then
      query=prompt("ID / identite / nom",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{
        {text="Tous",v=""},{text="Citoyens",v="citizen"},{text="Residents",v="resident"},
        {text="Suspendus",v="suspended"},{text="Decedes / archives",v="deceased"}
      })
      if st then status=st.v end
    elseif p.id=="reset" then
      query="";status=""
    elseif p.citizen then
      citizenDetails(p.citizen.id,info)
    end
  end
end


local function sessionTypeLabel(v)
  local labels={
    council="Conseil de la Coalition",cabinet="Conseil des ministres",
    emergency="Session d'urgence",committee="Commission",
    public_hearing="Audition publique"
  }
  return labels[v] or tostring(v or "")
end

local function chooseAgendaObject(kind)
  if kind=="law" then
    local law=chooseLaw("")
    return law and law.id,nil
  elseif kind=="bill" then
    local rows=rpc("NC_BILL_LIST",{}) or {}
    local items={}
    for _,x in ipairs(rows) do items[#items+1]={text=x.id.." ["..x.stage.."] "..x.title,row=x} end
    local p=menu("PROJETS DE LOI",items,#rows.." projet(s)")
    return p and p.row.id,nil
  elseif kind=="election" then
    local rows=rpc("NC_ELECTION_LIST",{}) or {}
    local items={}
    for _,x in ipairs(rows) do items[#items+1]={text=x.id.." ["..x.stage.."] "..x.title,row=x} end
    local p=menu("SCRUTINS",items,#rows.." scrutin(s)")
    return p and p.row.id,nil
  elseif kind=="decree" then
    local rows=rpc("NC_DECREE_LIST",{}) or {}
    local items={}
    for _,x in ipairs(rows) do items[#items+1]={text=x.id.." ["..x.status.."] "..x.title,row=x} end
    local p=menu("DECRETS",items,#rows.." decret(s)")
    return p and p.row.id,nil
  elseif kind=="case" then
    local rows=rpc("NC_CASE_LIST",{}) or {}
    local items={}
    for _,x in ipairs(rows) do items[#items+1]={text=x.id.." ["..x.status.."] "..x.title,row=x} end
    local p=menu("DOSSIERS NATIONAUX",items,#rows.." dossier(s)")
    return p and p.row.id,nil
  elseif kind=="ministry" then
    local rows=rpc("NC_MINISTRY_LIST",{}) or {}
    local items={}
    for _,x in ipairs(rows) do items[#items+1]={text=x.code.." "..x.name,row=x} end
    local p=menu("MINISTERES",items,#rows.." ministere(s)")
    return p and p.row.code,nil
  elseif kind=="citizen" then
    local rows=rpc("NC_CITIZEN_LIST",{}) or {}
    local items={}
    for _,x in ipairs(rows) do items[#items+1]={text=x.id.." ["..x.status.."] "..(x.displayName or x.identity),row=x} end
    local p=menu("REGISTRE CIVIL",items,#rows.." identite(s)")
    return p and p.row.id,nil
  elseif kind=="custom" then
    local title=prompt("Intitule du point libre")
    return title,title
  end
  return nil,nil
end

local function openAgendaObject(item,info)
  if item.kind=="law" then lawDetails(item.ref)
  elseif item.kind=="bill" then billDetails(item.ref)
  elseif item.kind=="election" then C.electionDetails(item.ref)
  elseif item.kind=="decree" then decreeDetails(item.ref)
  elseif item.kind=="case" then caseDetails(item.ref)
  elseif item.kind=="ministry" then ministryDetails(item.ref)
  elseif item.kind=="citizen" then citizenDetails(item.ref,info)
  else
    textPage(item.id or "POINT",{{label="Point libre",text=item.title or item.ref or ""},{label="Notes",text=item.notes or ""}})
  end
end

local function sessionDetails(id,info)
  while true do
    local sess,err=rpc("NC_SESSION_GET",{id=id})
    if not sess then message("SESSION NATIONALE",err,palette.bad);return end
    info=rpc("NC_INFO",{}) or info or {}
    local manager=(info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="council")
    local attendanceCount=0;for _ in pairs(sess.attendance or {}) do attendanceCount=attendanceCount+1 end

    local actions={
      {text="Lire la fiche / proces-verbal",id="read"},
      {text="Ordre du jour ("..tostring(#(sess.agenda or {}))..")",id="agenda"},
      {text="Presences ("..attendanceCount..")",id="attendance"},
      {text="Imprimer la session",id="print"}
    }
    if sess.status=="open" then actions[#actions+1]={text="Enregistrer ma presence",id="checkin"} end
    if manager and sess.status=="scheduled" then
      actions[#actions+1]={text="[+] Ajouter un point a l'ordre du jour",id="agenda_add"}
      actions[#actions+1]={text="Ouvrir officiellement la session",id="open"}
      actions[#actions+1]={text="Annuler la session",id="cancel"}
    elseif manager and sess.status=="open" then
      actions[#actions+1]={text="Piloter un point de l'ordre du jour",id="agenda_manage"}
      actions[#actions+1]={text="Clore et sceller le proces-verbal",id="close"}
      actions[#actions+1]={text="Annuler la session",id="cancel"}
    end

    local a=menu(sess.id.." - "..sess.title,actions,
      sessionTypeLabel(sess.sessionType).." / "..sess.status.." / "..(sess.scheduledFor or ""))
    if not a then return end

    if a.id=="read" then
      local agenda={}
      for _,x in ipairs(sess.agenda or {}) do
        agenda[#agenda+1]=(x.id or "?").." ["..(x.status or "?").."] "..(x.kind or "").." "..(x.ref or "")..
          "\n"..(x.title or "")..(x.sessionNotes and ("\nNotes: "..x.sessionNotes) or "")
      end
      local pres={}
      for _,x in pairs(sess.attendance or {}) do
        pres[#pres+1]=(x.identity or "?").." / "..roleLabel(x.role)..
          (x.ministryCode and (" / "..x.ministryCode) or "").." / "..(x.checkedInAt or "")
      end
      table.sort(pres)
      textPage(sess.id,{
        {label="Session",text=sess.title or ""},
        {label="Type / statut",text=sessionTypeLabel(sess.sessionType).." / "..(sess.status or "")},
        {label="Visibilite",text=sess.visibility or ""},
        {label="Date / heure",text=sess.scheduledFor or "-"},
        {label="Lieu",text=sess.location or "-"},
        {label="Description",text=sess.description or ""},
        {label="Convocation",text=sess.convocationSeal or "-"},
        {label="Ordre du jour",text=#agenda>0 and table.concat(agenda,"\n\n") or "Aucun point"},
        {label="Presences",text=#pres>0 and table.concat(pres,"\n") or "Aucune"},
        {label="Sceau d'ouverture",text=sess.openSeal or "-"},
        {label="Proces-verbal",text=sess.minutes or "-"},
        {label="Conclusions",text=sess.conclusions or "-"},
        {label="Sceau final",text=sess.closeSeal or sess.cancelSeal or "-"}
      })

    elseif a.id=="print" then
      local ok,pages=printer.session(sess)
      message("IMPRESSION",ok and ("Session imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)

    elseif a.id=="checkin" then
      local out,e=rpc("NC_SESSION_CHECKIN",{id=sess.id})
      message("PRESENCE",out and "Presence officiellement enregistree." or e,out and palette.accent or palette.bad)

    elseif a.id=="attendance" then
      local rows={}
      for _,x in pairs(sess.attendance or {}) do rows[#rows+1]={text=(x.identity or "?").." / "..roleLabel(x.role).." / "..(x.checkedInAt or ""),row=x} end
      table.sort(rows,function(x,y) return x.text<y.text end)
      local x=menu("PRESENCES / "..sess.id,rows,#rows.." participant(s)")
      if x then
        textPage("PRESENCE",{
          {label="Identite",text=x.row.identity or ""},{label="Citoyen",text=x.row.citizenId or ""},
          {label="Fonction",text=roleLabel(x.row.role)},{label="Ministere",text=x.row.ministryCode or "-"},
          {label="Enregistrement",text=x.row.checkedInAt or ""}
        })
      end

    elseif a.id=="agenda" then
      local items={}
      for _,x in ipairs(sess.agenda or {}) do items[#items+1]={text=(x.id or "?").." ["..(x.status or "?").."] "..(x.title or ""),item=x} end
      if #items==0 then message("ORDRE DU JOUR","Aucun point.",palette.muted)
      else
        local x=menu("ORDRE DU JOUR",items,#items.." point(s)")
        if x then
          local ops={{text="Ouvrir l'objet lie",id="open"}}
          if manager and sess.status=="scheduled" then ops[#ops+1]={text="Retirer ce point",id="remove"} end
          local y=menu(x.item.id,ops,(x.item.kind or "").." / "..(x.item.ref or ""))
          if y and y.id=="open" then openAgendaObject(x.item,info)
          elseif y and y.id=="remove" then
            local out,e=rpc("NC_SESSION_REMOVE_AGENDA",{id=sess.id,itemId=x.item.id})
            message("ORDRE DU JOUR",out and "Point retire." or e,out and palette.accent or palette.bad)
          end
        end
      end

    elseif a.id=="agenda_add" then
      local kind=menu("TYPE DE POINT",{
        {text="Article du Code national",v="law"},{text="Projet de loi",v="bill"},
        {text="Scrutin ministeriel",v="election"},{text="Decret",v="decree"},
        {text="Dossier judiciaire",v="case"},{text="Ministere",v="ministry"},
        {text="Citoyen / identite",v="citizen"},{text="Point libre",v="custom"}
      })
      if kind then
        local ref,customTitle=chooseAgendaObject(kind.v)
        if ref then
          local title=prompt("Titre du point (optionnel)",customTitle or "")
          local notes=multi("NOTES PREPARATOIRES","")
          local out,e=rpc("NC_SESSION_ADD_AGENDA",{id=sess.id,kind=kind.v,ref=ref,title=title,notes=notes})
          message("ORDRE DU JOUR",out and "Point ajoute." or e,out and palette.accent or palette.bad)
        end
      end

    elseif a.id=="open" then
      local out,e=rpc("NC_SESSION_OPEN",{id=sess.id})
      message("SESSION",out and ("Session ouverte / "..tostring(out.openSeal)) or e,out and palette.accent or palette.bad)

    elseif a.id=="agenda_manage" then
      local items={}
      for _,x in ipairs(sess.agenda or {}) do items[#items+1]={text=(x.id or "?").." ["..(x.status or "?").."] "..(x.title or ""),item=x} end
      local x=menu("PILOTER L'ORDRE DU JOUR",items,#items.." point(s)")
      if x then
        local st=menu("STATUT DU POINT",{
          {text="En attente",v="pending"},{text="En discussion",v="discussing"},
          {text="Discute",v="discussed"},{text="Vote",v="voted"},
          {text="Reporte",v="postponed"},{text="Retire",v="withdrawn"}
        },"Actuel: "..(x.item.status or ""))
        if st then
          local notes=prompt("Note de seance",x.item.sessionNotes or "")
          local out,e=rpc("NC_SESSION_SET_ITEM_STATUS",{id=sess.id,itemId=x.item.id,status=st.v,notes=notes})
          message("ORDRE DU JOUR",out and "Point mis a jour." or e,out and palette.accent or palette.bad)
        end
      end

    elseif a.id=="close" then
      local minutes=multi("PROCES-VERBAL COMPLET","")
      local conclusions=multi("CONCLUSIONS / DECISIONS DE SEANCE","")
      local out,e=rpc("NC_SESSION_CLOSE",{id=sess.id,minutes=minutes,conclusions=conclusions})
      message("SESSION",out and ("Session cloturee / "..tostring(out.closeSeal)) or e,out and palette.accent or palette.bad)

    elseif a.id=="cancel" then
      local reason=multi("MOTIF D'ANNULATION","")
      local out,e=rpc("NC_SESSION_CANCEL",{id=sess.id,reason=reason})
      message("SESSION",out and "Session annulee et tracee." or e,out and palette.accent or palette.bad)
    end
  end
end

local function sessionsScreen(info)
  local query,status="",""
  while true do
    local rows,err=rpc("NC_SESSION_LIST",{query=query,status=status})
    if not rows then message("SESSIONS",err,palette.bad);return end
    info=rpc("NC_INFO",{}) or info or {}
    local manager=(info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="council")
    local items={}
    if manager then items[#items+1]={text="[+] Convoquer une session",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser",id="reset"} end
    for _,sess in ipairs(rows) do
      items[#items+1]={text=sess.id.." ["..sess.status.."] "..sess.title.." / "..sessionTypeLabel(sess.sessionType),session=sess}
    end

    local p=menu("CALENDRIER / SESSIONS NATIONALES",items,#rows.." session(s)")
    if not p then return end
    if p.id=="new" then
      local typ=menu("TYPE DE SESSION",{
        {text="Conseil de la Coalition",v="council"},
        {text="Conseil des ministres",v="cabinet"},
        {text="Session d'urgence",v="emergency"},
        {text="Commission",v="committee"},
        {text="Audition publique",v="public_hearing"}
      })
      if typ then
        local title=prompt("Titre de la session")
        local scheduledFor=prompt("Date / heure RP")
        local location=prompt("Salle / lieu")
        local visibility=menu("VISIBILITE",{
          {text="Interne North Coalition",v="internal"},
          {text="Publique",v="public"},
          {text="Restreinte institutions",v="restricted"}
        })
        local description=multi("OBJET / DESCRIPTION DE LA SESSION","")
        local out,e=rpc("NC_SESSION_CREATE",{
          title=title,sessionType=typ.v,scheduledFor=scheduledFor,location=location,
          visibility=visibility and visibility.v or "internal",description=description
        })
        message("SESSION",out and ("Convoquee: "..out.id) or e,out and palette.accent or palette.bad)
      end
    elseif p.id=="search" then
      query=prompt("Recherche session",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{
        {text="Tous",v=""},{text="Prevues",v="scheduled"},{text="Ouvertes",v="open"},
        {text="Cloturees",v="closed"},{text="Annulees",v="cancelled"}
      })
      if st then status=st.v end
    elseif p.id=="reset" then query="";status=""
    elseif p.session then sessionDetails(p.session.id,info) end
  end
end


local function verifyNationalSealScreen(initial)
  local sealValue=common.trim(initial or "")
  while true do
    if sealValue=="" then sealValue=prompt("Sceau NC a verifier") end
    if sealValue=="" then return end
    local out,err=rpc("NC_VERIFY_SEAL",{seal=sealValue})
    if not out then
      message("VERIFICATION",err,palette.bad)
      return
    end
    if not out.valid then
      local a=menu("SCEAU INVALIDE",{
        {text="Verifier un autre sceau",id="again"},{text="Retour",id="back"}
      },"Aucun acte national correspondant: "..sealValue)
      if not a or a.id=="back" then return end
      sealValue=""
    else
      local status=out.confidential and "VALIDE / CONTENU RESTREINT" or "VALIDE"
      local a=menu("SCEAU "..status,{
        {text="Lire les informations de verification",id="read"},
        {text="Verifier un autre sceau",id="again"},
        {text="Retour",id="back"}
      },out.kind.." / "..tostring(out.objectId or ""))
      if not a or a.id=="back" then return end
      if a.id=="again" then sealValue=""
      elseif a.id=="read" then
        textPage("VERIFICATION OFFICIELLE",{
          {label="Resultat",text=status},
          {label="Sceau",text=out.seal or sealValue},
          {label="Nature",text=out.kind or ""},
          {label="Objet",text=out.objectId or "-"},
          {label="Titre",text=out.title or "-"},
          {label="Date",text=out.issuedAt or (out.confidential and "[restreinte]" or "-")},
          {label="Auteur / autorite",text=out.issuedBy or (out.confidential and "[restreint]" or "-")}
        })
      end
    end
  end
end


local function openGazetteObject(row,info)
  local kind=row.kind or ""
  if kind=="law_enactment" then billDetails(row.objectId)
  elseif kind=="decree" or kind=="decree_repeal" then decreeDetails(row.objectId)
  elseif kind=="ministry_appointment" or kind=="ministry_end" then ministryDetails(row.objectId)
  elseif kind=="election_result" then C.electionDetails(row.objectId)
  elseif kind=="session_minutes" then sessionDetails(row.objectId,info)
  elseif kind=="judgment" or kind=="appeal_decision" then caseDetails(row.objectId)
  elseif kind=="founding" then governmentScreen(info)
  else
    message("JOURNAL OFFICIEL","Aucun objet navigable pour cette publication.",palette.muted)
  end
end

local function gazetteDetails(id,info)
  while true do
    local row,err=rpc("NC_GAZETTE_GET",{id=id})
    if not row then message("JOURNAL OFFICIEL",err,palette.bad);return end
    local actions={
      {text="Lire la publication officielle",id="read"},
      {text="Ouvrir l'acte / objet source",id="source"},
      {text="Imprimer l'avis du Journal officiel",id="print"},
      {text="Verifier le sceau de publication",id="verify"}
    }
    local a=menu(row.id.." - "..row.title,actions,
      tostring(row.kind or "").." / "..tostring(row.publishedAt or "").." / "..tostring(row.visibility or "internal"))
    if not a then return end
    if a.id=="read" then
      textPage(row.id,{
        {label="Nature",text=row.kind or ""},
        {label="Objet source",text=row.objectId or ""},
        {label="Titre",text=row.title or ""},
        {label="Resume officiel",text=row.summary or ""},
        {label="Visibilite",text=row.visibility or ""},
        {label="Publication",text=(row.publishedAt or "-").." / "..(row.publishedBy or "-")},
        {label="Sceau de l'acte source",text=row.sourceSeal or "-"},
        {label="Sceau du Journal officiel",text=row.seal or "-"}
      })
    elseif a.id=="source" then
      openGazetteObject(row,info)
    elseif a.id=="print" then
      local ok,pages=printer.gazette(row)
      message("IMPRESSION",ok and ("Avis officiel imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="verify" then
      verifyNationalSealScreen(row.seal or "")
    end
  end
end

local function gazetteScreen(info)
  local query,kind="",""
  while true do
    local rows,err=rpc("NC_GAZETTE_LIST",{query=query,kind=kind})
    if not rows then message("JOURNAL OFFICIEL",err,palette.bad);return end
    local items={
      {text="[?] Rechercher une publication",id="search"},
      {text="[T] Filtrer par type"..(kind~="" and (" ["..kind.."]") or ""),id="kind"}
    }
    if query~="" or kind~="" then items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"} end
    for _,row in ipairs(rows) do
      items[#items+1]={
        text=row.id.." ["..tostring(row.kind or "?").."] "..tostring(row.title or ""),
        gazette=row
      }
    end
    local p=menu("JOURNAL OFFICIEL NORTH COALITION",items,#rows.." publication(s) visible(s)")
    if not p then return end
    if p.id=="search" then
      query=prompt("Recherche ID / titre / objet",query)
    elseif p.id=="kind" then
      local k=menu("TYPE DE PUBLICATION",{
        {text="Tous",v=""},{text="Promulgations de lois",v="law_enactment"},
        {text="Decrets",v="decree"},{text="Abrogations de decrets",v="decree_repeal"},
        {text="Nominations ministerielles",v="ministry_appointment"},
        {text="Fins de fonctions ministerielles",v="ministry_end"},
        {text="Resultats electoraux",v="election_result"},
        {text="Proces-verbaux de session",v="session_minutes"},
        {text="Jugements",v="judgment"},{text="Decisions d'appel",v="appeal_decision"},
        {text="Immatriculations",v="organization"},{text="Statuts d'organisations",v="organization_status"},
        {text="Actes fondateurs",v="founding"}
      })
      if k then kind=k.v end
    elseif p.id=="reset" then
      query="";kind=""
    elseif p.gazette then
      gazetteDetails(p.gazette.id,info)
    end
  end
end


local function chooseCitizen(title)
  local rows,err=rpc("NC_CITIZEN_LIST",{status="citizen"})
  if not rows then message("REGISTRE CIVIL",err,palette.bad);return nil end
  local items={}
  for _,cit in ipairs(rows) do
    items[#items+1]={text=cit.id.." / "..(cit.displayName or cit.identity),citizen=cit}
  end
  local p=menu(title or "CHOISIR UN CITOYEN",items,#items.." citoyen(s) actif(s)")
  return p and p.citizen or nil
end

local function chooseOrganization(title)
  local rows,err=rpc("NC_ORG_LIST",{status="active"})
  if not rows then message("ORGANISATIONS",err,palette.bad);return nil end
  local items={}
  for _,o in ipairs(rows) do items[#items+1]={text=o.id.." / "..o.name.." / "..o.kind,org=o} end
  local p=menu(title or "CHOISIR UNE ORGANISATION",items,#items.." organisation(s)")
  return p and p.org or nil
end

local function organizationDetails(id,info)
  while true do
    local o,err=rpc("NC_ORG_GET",{id=id})
    if not o then message("ORGANISATION",err,palette.bad);return end
    local canManage=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local actions={{text="Lire la fiche",id="read"},{text="Imprimer",id="print"}}
    if canManage then actions[#actions+1]={text="Modifier / suspendre / dissoudre",id="edit"} end
    local a=menu(o.id.." - "..o.name,actions,(o.kind or "").." / "..(o.status or ""))
    if not a then return end
    if a.id=="read" then
      local owners={}
      for _,x in ipairs(o.owners or {}) do owners[#owners+1]=(x.citizenId or "?").." / "..(x.identity or "") end
      local hist={}
      for _,h in ipairs(o.history or {}) do hist[#hist+1]=(h.at or "").." / "..(h.by or "").." / "..(h.oldStatus or "").." -> "..(h.newStatus or "").."\nSceau: "..(h.seal or "-") end
      textPage(o.id,{
        {label="Nom",text=o.name or ""},{label="Type / statut",text=(o.kind or "").." / "..(o.status or "")},
        {label="Activite",text=o.activity or ""},{label="Siege / adresse",text=o.registeredAddress or "-"},
        {label="Proprietaires / titulaires",text=#owners>0 and table.concat(owners,"\n") or "Aucun"},
        {label="Immatriculation",text=(o.createdAt or "-").." / "..(o.createdBy or "-")},
        {label="Sceau",text=o.registrationSeal or "-"},{label="Historique",text=#hist>0 and table.concat(hist,"\n\n") or "Aucune modification"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.organization(o)
      message("IMPRESSION",ok and ("Organisation imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="edit" then
      local name=prompt("Nom",o.name)
      local activity=prompt("Activite",o.activity)
      local address=prompt("Siege / adresse",o.registeredAddress or "")
      local st=menu("STATUT",{
        {text="Active",v="active"},{text="Suspendue",v="suspended"},{text="Dissoute",v="dissolved"}
      },"Actuel: "..(o.status or ""))
      local out,e=rpc("NC_ORG_UPDATE",{id=o.id,name=name,activity=activity,registeredAddress=address,status=st and st.v or o.status})
      message("ORGANISATION",out and "Registre mis a jour." or e,out and palette.accent or palette.bad)
    end
  end
end

local function organizationsScreen(info)
  local query,status="",""
  while true do
    local rows,err=rpc("NC_ORG_LIST",{query=query,status=status})
    if not rows then message("ORGANISATIONS",err,palette.bad);return end
    local canManage=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local items={}
    if canManage then items[#items+1]={text="[+] Immatriculer une organisation",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser",id="reset"} end
    for _,o in ipairs(rows) do items[#items+1]={text=o.id.." ["..o.status.."] "..o.name.." / "..o.kind,org=o} end
    local p=menu("REGISTRE DES ORGANISATIONS",items,#rows.." organisation(s)")
    if not p then return end
    if p.id=="new" then
      local kind=menu("TYPE",{
        {text="Entreprise",v="company"},{text="Association",v="association"},
        {text="Organisme public",v="public_body"},{text="Media",v="media"},
        {text="Banque",v="bank"},{text="Cooperative",v="cooperative"}
      })
      if kind then
        local name=prompt("Nom officiel")
        local activity=prompt("Activite principale")
        local address=prompt("Siege / adresse")
        local owners={}
        while true do
          local x=menu("PROPRIETAIRES / TITULAIRES",{
            {text="[+] Ajouter un citoyen",id="add"},{text="Terminer",id="done"}
          },"Actuellement: "..tostring(#owners))
          if not x or x.id=="done" then break end
          local cit=chooseCitizen("PROPRIETAIRE")
          if cit then owners[#owners+1]=cit.id end
        end
        local out,e=rpc("NC_ORG_CREATE",{name=name,kind=kind.v,activity=activity,registeredAddress=address,ownerCitizenIds=owners})
        message("ORGANISATION",out and ("Immatriculee: "..out.id) or e,out and palette.accent or palette.bad)
      end
    elseif p.id=="search" then query=prompt("Recherche",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{{text="Tous",v=""},{text="Actives",v="active"},{text="Suspendues",v="suspended"},{text="Dissoutes",v="dissolved"}})
      if st then status=st.v end
    elseif p.id=="reset" then query="";status=""
    elseif p.org then organizationDetails(p.org.id,info) end
  end
end

local function licenseDetails(id,info)
  while true do
    local l,err=rpc("NC_LICENSE_GET",{id=id})
    if not l then message("LICENCE",err,palette.bad);return end
    local isMinister=info.nationalRole=="minister"
    local canManage=(info.nationalRole=="admin" or info.nationalRole=="president" or isMinister)
    local actions={{text="Lire la licence",id="read"},{text="Imprimer",id="print"}}
    if canManage then actions[#actions+1]={text="Modifier le statut",id="status"} end
    local a=menu(l.id.." - "..l.title,actions,(l.kind or "").." / "..(l.status or "").." / "..(l.holderName or l.holderId or ""))
    if not a then return end
    if a.id=="read" then
      local hist={}
      for _,h in ipairs(l.history or {}) do hist[#hist+1]=(h.at or "").." / "..(h.old or "").." -> "..(h.new or "").." / "..(h.reason or "").."\nSceau: "..(h.seal or "-") end
      textPage(l.id,{
        {label="Titre",text=l.title or ""},{label="Type / statut",text=(l.kind or "").." / "..(l.status or "")},
        {label="Titulaire",text=(l.holderId or "").." / "..(l.holderName or "")},
        {label="Autorite",text=l.authority or ""},{label="Base legale",text=l.legalBasis or "-"},
        {label="Conditions",text=l.conditions or "-"},{label="Notes",text=l.notes or "-"},
        {label="Delivree",text=(l.issuedAt or "-").." / "..(l.issuedBy or "-")},
        {label="Expiration",text=l.expiresAt or "-"},{label="Sceau",text=l.seal or "-"},
        {label="Historique",text=#hist>0 and table.concat(hist,"\n\n") or "Aucune modification"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.license(l)
      message("IMPRESSION",ok and ("Licence imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="status" then
      local st=menu("STATUT DE LICENCE",{
        {text="Active",v="active"},{text="Suspendue",v="suspended"},
        {text="Revoquee",v="revoked"},{text="Expiree",v="expired"}
      },"Actuel: "..(l.status or ""))
      if st then
        local reason=prompt("Motif")
        local out,e=rpc("NC_LICENSE_SET_STATUS",{id=l.id,status=st.v,reason=reason})
        message("LICENCE",out and ("Statut: "..out.status) or e,out and palette.accent or palette.bad)
      end
    end
  end
end

local function licensesScreen(info)
  local query,status="",""
  while true do
    local rows,err=rpc("NC_LICENSE_LIST",{query=query,status=status})
    if not rows then message("LICENCES",err,palette.bad);return end
    local canIssue=(info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="minister")
    local items={}
    if canIssue then items[#items+1]={text="[+] Delivrer une licence / autorisation",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser",id="reset"} end
    for _,l in ipairs(rows) do items[#items+1]={text=l.id.." ["..l.status.."] "..l.title.." / "..(l.holderName or l.holderId),license=l} end
    local p=menu("LICENCES / AUTORISATIONS",items,#rows.." licence(s) visible(s)")
    if not p then return end
    if p.id=="new" then
      local kinds={
        {text="Commerce / entreprise",v="business"},{text="Banque / finance",v="bank"},
        {text="Conduite",v="driving"},{text="Vehicule / transport",v="vehicle"},
        {text="Construction",v="construction"},{text="Securite",v="security"},
        {text="Armes / port reglemente",v="weapons"},{text="Medical / sante",v="medical"},
        {text="Cyber / numerique",v="cyber"},{text="Matieres dangereuses",v="hazardous"},
        {text="Travail / professionnel",v="labor"},{text="Defense",v="defense"},
        {text="Reconstruction / crise",v="reconstruction"},{text="Affaires etrangeres",v="foreign"},
        {text="Generique presidentiel",v="generic"}
      }
      local kind=menu("TYPE DE LICENCE",kinds)
      if kind then
        local holderType=menu("TITULAIRE",{{text="Citoyen",v="citizen"},{text="Organisation",v="organization"}})
        local holder=nil
        if holderType and holderType.v=="citizen" then holder=chooseCitizen("TITULAIRE DE LA LICENCE")
        elseif holderType then holder=chooseOrganization("ORGANISATION TITULAIRE") end
        if holder then
          local title=prompt("Titre de la licence","Licence "..kind.v)
          local legalBasis=prompt("Base legale NC-ART-... (optionnel)")
          local expiresAt=prompt("Expiration / echeance RP (optionnel)")
          local conditions=multi("CONDITIONS DE LA LICENCE","")
          local notes=multi("NOTES ADMINISTRATIVES","")
          local out,e=rpc("NC_LICENSE_ISSUE",{
            kind=kind.v,title=title,holderType=holderType.v,holderId=holder.id,
            legalBasis=legalBasis,expiresAt=expiresAt,conditions=conditions,notes=notes
          })
          message("LICENCE",out and ("Delivree: "..out.id) or e,out and palette.accent or palette.bad)
        end
      end
    elseif p.id=="search" then query=prompt("Recherche licence",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{{text="Tous",v=""},{text="Actives",v="active"},{text="Suspendues",v="suspended"},{text="Revoquees",v="revoked"},{text="Expirees",v="expired"}})
      if st then status=st.v end
    elseif p.id=="reset" then query="";status=""
    elseif p.license then licenseDetails(p.license.id,info) end
  end
end

local function fineDetails(id,info)
  while true do
    local fine,err=rpc("NC_FINE_GET",{id=id})
    if not fine then message("AMENDE",err,palette.bad);return end
    local judicial=(info.nationalRole=="admin" or info.nationalRole=="judge" or info.nationalRole=="prosecutor")
    local finance=(info.nationalRole=="admin" or info.nationalRole=="judge" or info.nationalRole=="prosecutor" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local own=(info.citizenId and info.citizenId==fine.citizenId)
    local actions={{text="Lire l'amende",id="read"},{text="Imprimer",id="print"}}
    if own and fine.status=="issued" then actions[#actions+1]={text="Contester cette amende",id="contest"} end
    if judicial and fine.status=="contested" then actions[#actions+1]={text="Trancher la contestation",id="resolve"} end
    if finance and fine.status=="issued" then actions[#actions+1]={text="Enregistrer paiement",id="paid"} end
    if judicial and fine.status~="paid" and fine.status~="void" then actions[#actions+1]={text="Annuler l'amende",id="void"} end
    local a=menu(fine.id,actions,(fine.status or "").." / "..(fine.citizenIdentity or fine.citizenId).." / "..tostring(fine.penaltyUnits or 0).." UP")
    if not a then return end
    if a.id=="read" then
      local hist={}
      for _,h in ipairs(fine.history or {}) do hist[#hist+1]=(h.at or "").." / "..(h.event or "").." / "..(h.by or "").." / "..(h.reason or h.decision or h.paymentRef or "").."\nSceau: "..(h.seal or "-") end
      textPage(fine.id,{
        {label="Citoyen",text=(fine.citizenId or "").." / "..(fine.citizenIdentity or "")},
        {label="Statut",text=fine.status or ""},{label="Article",text=(fine.articleDisplay or fine.articleRef or "").." / v"..tostring(fine.articleVersion or "")},
        {label="Motif",text=fine.reason or ""},{label="Penalite",text=tostring(fine.penaltyUnits or 0).." UP"..((fine.amountText and fine.amountText~="") and (" / "..fine.amountText) or "")},
        {label="Emission",text=(fine.issuedAt or "").." / "..(fine.issuedBy or "")},
        {label="Contestation",text=fine.contestReason or "-"},
        {label="Decision contestation",text=(fine.contestDecision or "-").." / "..(fine.contestDecisionReason or "-")},
        {label="Paiement",text=fine.paidAt and ((fine.paidAt or "").." / "..(fine.paymentRef or "-")) or "-"},
        {label="Annulation",text=fine.voidReason or "-"},
        {label="Sceau",text=fine.seal or "-"},
        {label="Historique",text=#hist>0 and table.concat(hist,"\n\n") or "Aucun"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.fine(fine)
      message("IMPRESSION",ok and ("Amende imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="contest" then
      local reason=multi("MOTIFS DE CONTESTATION","")
      local out,e=rpc("NC_FINE_CONTEST",{id=fine.id,reason=reason})
      message("CONTESTATION",out and "Contestation enregistree." or e,out and palette.accent or palette.bad)
    elseif a.id=="resolve" then
      local d=menu("DECISION",{{text="Maintenir l'amende",v="upheld"},{text="Annuler l'amende",v="void"}})
      if d then
        local reasoning=multi("MOTIVATION DE LA DECISION","")
        local out,e=rpc("NC_FINE_RESOLVE",{id=fine.id,decision=d.v,reasoning=reasoning})
        message("DECISION",out and ("Decision: "..d.v) or e,out and palette.accent or palette.bad)
      end
    elseif a.id=="paid" then
      local paymentRef=prompt("Reference de paiement / justificatif")
      local out,e=rpc("NC_FINE_MARK_PAID",{id=fine.id,paymentRef=paymentRef})
      message("PAIEMENT",out and "Paiement enregistre." or e,out and palette.accent or palette.bad)
    elseif a.id=="void" then
      local reason=multi("MOTIF D'ANNULATION","")
      local out,e=rpc("NC_FINE_VOID",{id=fine.id,reason=reason})
      message("AMENDE",out and "Amende annulee." or e,out and palette.accent or palette.bad)
    end
  end
end

local function finesScreen(info)
  local query,status="",""
  while true do
    local rows,err=rpc("NC_FINE_LIST",{query=query,status=status})
    if not rows then message("AMENDES",err,palette.bad);return end
    local canIssue=(info.nationalRole=="admin" or info.nationalRole=="judge" or info.nationalRole=="prosecutor" or info.nationalRole=="police")
    local items={}
    if canIssue then items[#items+1]={text="[+] Emettre une amende",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser",id="reset"} end
    for _,fine in ipairs(rows) do
      items[#items+1]={text=fine.id.." ["..fine.status.."] "..(fine.citizenIdentity or fine.citizenId).." / "..tostring(fine.penaltyUnits or 0).." UP",fine=fine}
    end
    local p=menu("AMENDES / SANCTIONS PECUNIAIRES",items,#rows.." amende(s) visible(s)")
    if not p then return end
    if p.id=="new" then
      local cit=chooseCitizen("CITOYEN VERBALISE")
      if cit then
        local law=chooseLaw("")
        if law then
          local units=prompt("Unites de penalite (UP)","1")
          local amountText=prompt("Equivalent monetaire / note (optionnel)")
          local reason=prompt("Motif",law.title)
          local out,e=rpc("NC_FINE_ISSUE",{citizenId=cit.id,articleRef=law.id,penaltyUnits=tonumber(units),amountText=amountText,reason=reason})
          message("AMENDE",out and ("Emise: "..out.id) or e,out and palette.accent or palette.bad)
        end
      end
    elseif p.id=="search" then query=prompt("Recherche amende / citoyen / article",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{{text="Tous",v=""},{text="Emises",v="issued"},{text="Contestees",v="contested"},{text="Payees",v="paid"},{text="Annulees",v="void"}})
      if st then status=st.v end
    elseif p.id=="reset" then query="";status=""
    elseif p.fine then fineDetails(p.fine.id,info) end
  end
end

local function citizenRecordScreen(info)
  local citizenId=info.citizenId
  if info.nationalRole=="admin" or info.nationalRole=="judge" or info.nationalRole=="prosecutor" or info.nationalRole=="police" then
    local cit=chooseCitizen("DOSSIER INDIVIDUEL")
    if not cit then return end
    citizenId=cit.id
  end
  if not citizenId then message("DOSSIER INDIVIDUEL","Aucune identite citoyenne rattachee a ce terminal.",palette.warn);return end
  local record,err=rpc("NC_RECORD_GET",{citizenId=citizenId})
  if not record then message("DOSSIER INDIVIDUEL",err,palette.bad);return end
  local licenses,fines,orgs,judgments={},{},{},{}
  for _,x in ipairs(record.licenses or {}) do licenses[#licenses+1]=x.id.." ["..x.status.."] "..x.title end
  for _,x in ipairs(record.fines or {}) do fines[#fines+1]=x.id.." ["..x.status.."] "..tostring(x.penaltyUnits or 0).." UP / "..(x.articleDisplay or x.articleRef or "") end
  for _,x in ipairs(record.organizations or {}) do orgs[#orgs+1]=x.id.." ["..x.status.."] "..x.name end
  for _,x in ipairs(record.judgments or {}) do judgments[#judgments+1]=(x.caseId or "").." / "..(x.judgmentId or "").." / "..(x.verdict or "") end
  local a=menu("DOSSIER INDIVIDUEL / "..record.citizen.id,{
    {text="Lire la synthese",id="read"},{text="Imprimer le dossier",id="print"}
  },record.citizen.displayName or record.citizen.identity)
  if not a then return end
  if a.id=="read" then
    textPage(record.citizen.id,{
      {label="Citoyen",text=(record.citizen.displayName or "").." / "..(record.citizen.identity or "")},
      {label="Statut",text=record.citizen.status or ""},
      {label="Licences",text=#licenses>0 and table.concat(licenses,"\n") or "Aucune"},
      {label="Amendes",text=#fines>0 and table.concat(fines,"\n") or "Aucune"},
      {label="Organisations",text=#orgs>0 and table.concat(orgs,"\n") or "Aucune"},
      {label="Jugements definitifs lies",text=#judgments>0 and table.concat(judgments,"\n") or "Aucun"}
    })
  elseif a.id=="print" then
    local ok,pages=printer.citizenRecord(record)
    message("IMPRESSION",ok and ("Dossier citoyen imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
  end
end


local function requestDetails(id,info)
  while true do
    local req,err=rpc("NC_REQUEST_GET",{id=id})
    if not req then message("GUICHET ADMINISTRATIF",err,palette.bad);return end
    info=rpc("NC_INFO",{}) or info or {}
    local reviewer=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode==req.targetMinistry))
    local own=(info.citizenId and info.citizenId==req.applicantCitizenId)

    local actions={{text="Lire la demande complete",id="read"},{text="Imprimer",id="print"}}
    if req.resultObjectId then actions[#actions+1]={text="Ouvrir l'autorisation / objet cree",id="result"} end
    if reviewer and req.status=="submitted" then actions[#actions+1]={text="Prendre en instruction",id="review"} end
    if reviewer and (req.status=="submitted" or req.status=="in_review") then
      actions[#actions+1]={text="APPROUVER la demande",id="approve"}
      actions[#actions+1]={text="REJETER la demande",id="reject"}
    end
    if own and (req.status=="submitted" or req.status=="in_review") then actions[#actions+1]={text="Retirer ma demande",id="withdraw"} end

    local a=menu(req.id.." - "..req.title,actions,
      (req.requestType or "").." / "..(req.status or "").." / "..(req.targetMinistry or ""))
    if not a then return end

    if a.id=="read" then
      local hist={}
      for _,h in ipairs(req.history or {}) do hist[#hist+1]=(h.at or "").." / "..(h.event or "").." / "..(h.by or "").."\n"..(h.details or "").."\nSceau: "..(h.seal or "-") end
      local payload={}
      if req.requestType=="license" then
        payload[#payload+1]="Type: "..tostring((req.payload or {}).kind or "")
        payload[#payload+1]="Titre: "..tostring((req.payload or {}).title or "")
        payload[#payload+1]="Expiration: "..tostring((req.payload or {}).expiresAt or "-")
        payload[#payload+1]="Conditions souhaitees: "..tostring((req.payload or {}).conditionsRequested or "-")
      elseif req.requestType=="organization" then
        payload[#payload+1]="Nom: "..tostring((req.payload or {}).name or "")
        payload[#payload+1]="Type: "..tostring((req.payload or {}).kind or "")
        payload[#payload+1]="Activite: "..tostring((req.payload or {}).activity or "")
        payload[#payload+1]="Siege: "..tostring((req.payload or {}).registeredAddress or "-")
      end
      textPage(req.id,{
        {label="Type / statut",text=(req.requestType or "").." / "..(req.status or "")},
        {label="Demandeur",text=(req.applicantCitizenId or "").." / "..(req.applicantIdentity or "")},
        {label="Administration competente",text=req.targetMinistry or ""},
        {label="Titre",text=req.title or ""},{label="Objet / motivation",text=req.body or ""},
        {label="Base legale",text=req.legalBasis or "-"},
        {label="Details",text=#payload>0 and table.concat(payload,"\n") or "-"},
        {label="Depot",text=(req.createdAt or "").." / "..(req.createdBy or "")},
        {label="Sceau de depot",text=req.seal or "-"},
        {label="Decision",text=(req.decision or "-").." / "..(req.decisionReason or "-")},
        {label="Objet cree",text=req.resultObjectId or "-"},
        {label="Sceau de decision",text=req.decisionSeal or "-"},
        {label="Historique",text=#hist>0 and table.concat(hist,"\n\n") or "Aucun"}
      })

    elseif a.id=="print" then
      local ok,pages=printer.request(req)
      message("IMPRESSION",ok and ("Demande imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)

    elseif a.id=="result" then
      if tostring(req.resultObjectId):find("^NC%-LIC%-") then licenseDetails(req.resultObjectId,info)
      elseif tostring(req.resultObjectId):find("^NC%-ORG%-") then organizationDetails(req.resultObjectId,info)
      else message("GUICHET","Objet resultat: "..tostring(req.resultObjectId),palette.info) end

    elseif a.id=="review" then
      local note=prompt("Note d'instruction")
      local out,e=rpc("NC_REQUEST_START_REVIEW",{id=req.id,note=note})
      message("GUICHET",out and "Demande prise en instruction." or e,out and palette.accent or palette.bad)

    elseif a.id=="approve" or a.id=="reject" then
      local decision=a.id=="approve" and "approved" or "rejected"
      local reasoning=multi("MOTIVATION DE LA DECISION","")
      local conditions=""
      if decision=="approved" and req.requestType=="license" then conditions=multi("CONDITIONS DEFINITIVES DE LA LICENCE",(req.payload or {}).conditionsRequested or "") end
      local out,e=rpc("NC_REQUEST_DECIDE",{id=req.id,decision=decision,reasoning=reasoning,conditions=conditions})
      message("DECISION",out and (decision=="approved" and ("APPROUVEE"..(out.resultObjectId and (" / "..out.resultObjectId) or "")) or "REJETEE") or e,
        out and (decision=="approved" and palette.accent or palette.warn) or palette.bad)

    elseif a.id=="withdraw" then
      local reason=prompt("Motif du retrait")
      local out,e=rpc("NC_REQUEST_WITHDRAW",{id=req.id,reason=reason})
      message("GUICHET",out and "Demande retiree." or e,out and palette.accent or palette.bad)
    end
  end
end

local function requestsScreen(info)
  local query,status="",""
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local rows,err=rpc("NC_REQUEST_LIST",{query=query,status=status})
    if not rows then message("GUICHET ADMINISTRATIF",err,palette.bad);return end
    local items={}
    if info.citizenId and info.citizenStatus=="citizen" then items[#items+1]={text="[+] Deposer une nouvelle demande",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser",id="reset"} end
    for _,req in ipairs(rows) do
      items[#items+1]={text=req.id.." ["..req.status.."] "..req.title.." / "..req.targetMinistry,request=req}
    end
    local p=menu("GUICHET CITOYEN / DEMANDES",items,#rows.." demande(s) visible(s)")
    if not p then return end

    if p.id=="new" then
      local typ=menu("TYPE DE DEMANDE",{
        {text="Demande de licence / permis",v="license"},
        {text="Immatriculation d'une organisation",v="organization"},
        {text="Demande administrative libre",v="administrative"}
      })
      if typ and typ.v=="license" then
        local kind=menu("TYPE DE LICENCE",{
          {text="Commerce / entreprise",v="business"},{text="Banque / finance",v="bank"},
          {text="Conduite",v="driving"},{text="Vehicule / transport",v="vehicle"},
          {text="Construction",v="construction"},{text="Securite",v="security"},
          {text="Armes / port reglemente",v="weapons"},{text="Medical / sante",v="medical"},
          {text="Cyber / numerique",v="cyber"},{text="Matieres dangereuses",v="hazardous"},
          {text="Travail / professionnel",v="labor"},{text="Defense",v="defense"},
          {text="Reconstruction / crise",v="reconstruction"},{text="Affaires etrangeres",v="foreign"}
        })
        if kind then
          local title=prompt("Titre de la demande","Demande de licence "..kind.v)
          local licenseTitle=prompt("Intitule souhaite de la licence","Licence "..kind.v)
          local legalBasis=prompt("Base legale NC-ART-... (optionnel)")
          local expiresAt=prompt("Echeance souhaitee (optionnel)")
          local conditions=multi("CONDITIONS / JUSTIFICATIFS PROPOSES","")
          local body=multi("MOTIVATION DE LA DEMANDE","")
          local out,e=rpc("NC_REQUEST_CREATE",{
            requestType="license",title=title,body=body,licenseKind=kind.v,
            licenseTitle=licenseTitle,legalBasis=legalBasis,expiresAt=expiresAt,
            conditionsRequested=conditions
          })
          message("GUICHET",out and ("Deposee: "..out.id.." / "..out.targetMinistry) or e,out and palette.accent or palette.bad)
        end
      elseif typ and typ.v=="organization" then
        local kind=menu("TYPE D'ORGANISATION",{
          {text="Entreprise",v="company"},{text="Association",v="association"},
          {text="Organisme public",v="public_body"},{text="Media",v="media"},
          {text="Banque",v="bank"},{text="Cooperative",v="cooperative"}
        })
        if kind then
          local name=prompt("Nom officiel")
          local activity=prompt("Activite principale")
          local address=prompt("Siege / adresse")
          local title=prompt("Titre de la demande","Immatriculation de "..name)
          local body=multi("MOTIVATION / PRESENTATION","")
          local out,e=rpc("NC_REQUEST_CREATE",{
            requestType="organization",title=title,body=body,organizationKind=kind.v,
            organizationName=name,activity=activity,registeredAddress=address
          })
          message("GUICHET",out and ("Deposee: "..out.id.." / MIN-ECO") or e,out and palette.accent or palette.bad)
        end
      elseif typ and typ.v=="administrative" then
        local ministries=rpc("NC_MINISTRY_LIST",{}) or {}
        local choices={{text="Presidence de la Coalition",code="PRESIDENCE"}}
        for _,m in ipairs(ministries) do choices[#choices+1]={text=m.code.." / "..m.name,code=m.code} end
        local target=menu("ADMINISTRATION DESTINATAIRE",choices)
        if target then
          local title=prompt("Titre de la demande")
          local legalBasis=prompt("Base legale NC-ART-... (optionnel)")
          local body=multi("DEMANDE / MOTIVATION","")
          local out,e=rpc("NC_REQUEST_CREATE",{requestType="administrative",targetMinistry=target.code,title=title,legalBasis=legalBasis,body=body})
          message("GUICHET",out and ("Deposee: "..out.id.." / "..out.targetMinistry) or e,out and palette.accent or palette.bad)
        end
      end

    elseif p.id=="search" then query=prompt("Recherche demande",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{
        {text="Tous",v=""},{text="Deposees",v="submitted"},{text="En instruction",v="in_review"},
        {text="Approuvees",v="approved"},{text="Rejetees",v="rejected"},{text="Retirees",v="withdrawn"}
      })
      if st then status=st.v end
    elseif p.id=="reset" then query="";status=""
    elseif p.request then requestDetails(p.request.id,info) end
  end
end

local function administrationScreen(info)
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local items={
      {text="GUICHET CITOYEN / DEMANDES ADMINISTRATIVES",id="requests"},
      {text="REGISTRE DES ORGANISATIONS / ENTREPRISES",id="orgs"},
      {text="LICENCES / AUTORISATIONS / PERMIS",id="licenses"},
      {text="AMENDES / SANCTIONS PECUNIAIRES",id="fines"},
      {text="DOSSIER INDIVIDUEL / SYNTHESE",id="record"}
    }
    local p=menu("ADMINISTRATION NATIONALE",items,
      roleLabel(info.nationalRole)..(info.ministryCode and (" / "..info.ministryCode) or ""))
    if not p then return end
    if p.id=="requests" then requestsScreen(info)
    elseif p.id=="orgs" then organizationsScreen(info)
    elseif p.id=="licenses" then licensesScreen(info)
    elseif p.id=="fines" then finesScreen(info)
    elseif p.id=="record" then citizenRecordScreen(info) end
  end
end


local function money(v,unit)
  return tostring(tonumber(v) or 0).." "..tostring(unit or "UB")
end

local function budgetDetails(id,info)
  while true do
    local b,err=rpc("NC_BUDGET_GET",{id=id})
    if not b then message("BUDGET",err,palette.bad);return end
    info=rpc("NC_INFO",{}) or info or {}
    local financeManager=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local voteManager=(info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="council")
    local president=(info.nationalRole=="admin" or info.nationalRole=="president")
    local unit=(rpc("NC_TREASURY_DASHBOARD",{}) or {}).unit or "UB"

    local actions={{text="Lire le budget complet",id="read"},{text="Imprimer le budget",id="print"}}
    if financeManager and b.status=="draft" then
      actions[#actions+1]={text="Modifier les credits par ministere",id="alloc"}
      actions[#actions+1]={text="Ouvrir le vote du Conseil",id="open_vote"}
    elseif b.status=="voting" then
      actions[#actions+1]={text="Voter sur le budget",id="vote"}
      if voteManager then actions[#actions+1]={text="Clore le vote",id="close_vote"} end
    elseif b.status=="adopted" and president then
      actions[#actions+1]={text="Promulguer le budget",id="enact"}
    end

    local a=menu(b.id.." - "..b.title,actions,
      tostring(b.fiscalYear).." / "..b.status.." / total "..money(b.totalUB,unit))
    if not a then return end

    if a.id=="read" then
      local alloc={}
      for code,amount in pairs(b.allocations or {}) do
        local ex=(b.execution or {})[code] or {}
        alloc[#alloc+1]=code.." : "..money(amount,unit)..
          " / engage "..money(ex.committedUB,unit)..
          " / paye "..money(ex.spentUB,unit)..
          " / dispo "..money(ex.availableUB,unit)
      end
      table.sort(alloc)
      local t=b.tally or {}
      textPage(b.id,{
        {label="Exercice",text=tostring(b.fiscalYear or "")},
        {label="Statut",text=b.status or ""},
        {label="Titre",text=b.title or ""},
        {label="Recettes attendues",text=money(b.expectedRevenueUB,unit)},
        {label="Reserve nationale",text=money(b.reserveUB,unit)},
        {label="Credits ministeriels",text=#alloc>0 and table.concat(alloc,"\n") or "Aucun"},
        {label="Vote",text="Pour "..tostring(t.yes or 0).." / Contre "..tostring(t.no or 0)..
          " / Abstention "..tostring(t.abstain or 0).." / participation "..tostring(t.participation or 0).."/"..tostring(t.eligible or 0)},
        {label="Sceaux",text=(b.seal or "-").."\n"..(b.voteOpenSeal or "-").."\n"..(b.voteSeal or "-").."\n"..(b.enactmentSeal or "-")},
        {label="Journal officiel",text=b.gazetteId or "-"},
        {label="Notes",text=b.notes or "-"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.budget(b,unit)
      message("IMPRESSION",ok and ("Budget imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="alloc" then
      local ministries=rpc("NC_MINISTRY_LIST",{}) or {}
      local items={}
      for _,m in ipairs(ministries) do
        items[#items+1]={text=m.code.." "..m.name.." / actuel "..money((b.allocations or {})[m.code],unit),m=m}
      end
      local x=menu("CREDITS MINISTERIELS",items,#items.." ministere(s)")
      if x then
        local amount=tonumber(prompt("Nouveau credit "..unit,tostring((b.allocations or {})[x.m.code] or 0)))
        local out,e=rpc("NC_BUDGET_SET_ALLOCATION",{id=b.id,ministryCode=x.m.code,amountUB=amount})
        message("BUDGET",out and "Credit mis a jour." or e,out and palette.accent or palette.bad)
      end
    elseif a.id=="open_vote" then
      local out,e=rpc("NC_BUDGET_OPEN_VOTE",{id=b.id})
      message("BUDGET",out and "Vote budgetaire ouvert." or e,out and palette.accent or palette.bad)
    elseif a.id=="vote" then
      local v=menu("VOTE BUDGETAIRE",{
        {text="POUR",v="yes"},{text="CONTRE",v="no"},{text="ABSTENTION",v="abstain"}
      })
      if v then
        local out,e=rpc("NC_BUDGET_VOTE",{id=b.id,choice=v.v})
        message("VOTE",out and "Vote enregistre." or e,out and palette.accent or palette.bad)
      end
    elseif a.id=="close_vote" then
      local out,e=rpc("NC_BUDGET_CLOSE_VOTE",{id=b.id})
      message("BUDGET",out and ("Resultat: "..tostring(out.result or out.status)) or e,
        out and ((out.status=="adopted") and palette.accent or palette.warn) or palette.bad)
    elseif a.id=="enact" then
      local out,e=rpc("NC_BUDGET_ENACT",{id=b.id})
      message("BUDGET",out and ("Budget promulgue / "..tostring(out.enactmentSeal)) or e,out and palette.accent or palette.bad)
    end
  end
end

local function budgetsScreen(info)
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local rows,err=rpc("NC_BUDGET_LIST",{})
    if not rows then message("BUDGETS",err,palette.bad);return end
    local canCreate=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local items={}
    if canCreate then items[#items+1]={text="[+] Preparer un nouveau budget",id="new"} end
    for _,b in ipairs(rows) do
      items[#items+1]={text=b.id.." ["..b.status.."] exercice "..tostring(b.fiscalYear).." / "..b.title,budget=b}
    end
    local p=menu("BUDGETS NATIONAUX",items,#rows.." budget(s)")
    if not p then return end
    if p.id=="new" then
      local fiscal=prompt("Exercice budgetaire",os.date and os.date("%Y") or "")
      local title=prompt("Titre","Budget national "..fiscal)
      local revenue=tonumber(prompt("Recettes attendues (UB)","0"))
      local reserve=tonumber(prompt("Reserve nationale (UB)","0"))
      local notes=multi("ORIENTATIONS BUDGETAIRES","")
      local out,e=rpc("NC_BUDGET_CREATE",{fiscalYear=fiscal,title=title,expectedRevenueUB=revenue,reserveUB=reserve,notes=notes})
      message("BUDGET",out and ("Cree: "..out.id) or e,out and palette.accent or palette.bad)
    elseif p.budget then budgetDetails(p.budget.id,info) end
  end
end

local function revenueDetails(id)
  local rows=rpc("NC_REVENUE_LIST",{query=id}) or {}
  local row=nil
  for _,x in ipairs(rows) do if x.id==id then row=x break end end
  if not row then message("RECETTE","Recette introuvable.",palette.bad);return end
  local a=menu(row.id.." - "..row.title,{
    {text="Lire la recette",id="read"},{text="Imprimer",id="print"}
  },row.kind.." / +"..money(row.amountUB,"UB"))
  if not a then return end
  if a.id=="read" then
    textPage(row.id,{
      {label="Nature",text=row.kind or ""},{label="Titre",text=row.title or ""},
      {label="Montant",text=money(row.amountUB,"UB")},{label="Source",text=row.source or "-"},
      {label="Base legale",text=row.legalBasis or "-"},{label="Date",text=row.recordedAt or ""},
      {label="Enregistre par",text=row.recordedBy or ""},{label="Notes",text=row.notes or "-"},
      {label="Sceau",text=row.seal or "-"}
    })
  elseif a.id=="print" then
    local ok,pages=printer.revenue(row,"UB")
    message("IMPRESSION",ok and ("Recette imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
  end
end

local function revenuesScreen(info)
  local query=""
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local rows,err=rpc("NC_REVENUE_LIST",{query=query})
    if not rows then message("RECETTES",err,palette.bad);return end
    local canCreate=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local items={}
    if canCreate then items[#items+1]={text="[+] Enregistrer une recette",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    for _,r in ipairs(rows) do items[#items+1]={text=r.id.." +"..money(r.amountUB,"UB").." / "..r.title,revenue=r} end
    local p=menu("RECETTES / TRESORERIE",items,#rows.." recette(s)")
    if not p then return end
    if p.id=="new" then
      local k=menu("NATURE DE RECETTE",{
        {text="Solde initial",v="opening_balance"},{text="Impot / taxe",v="tax"},
        {text="Douanes",v="customs"},{text="Amende",v="fine"},{text="Frais / redevance",v="fee"},
        {text="Dividende public",v="dividend"},{text="Subvention / aide",v="grant"},{text="Autre",v="other"}
      })
      if k then
        local title=prompt("Titre de la recette")
        local amount=tonumber(prompt("Montant (UB)","0"))
        local source=prompt("Source / payeur")
        local legalBasis=prompt("Base legale NC-ART-... (si requise)")
        local notes=multi("NOTES DE TRESORERIE","")
        local out,e=rpc("NC_REVENUE_RECORD",{kind=k.v,title=title,amountUB=amount,source=source,legalBasis=legalBasis,notes=notes})
        message("RECETTE",out and ("Enregistree: "..out.id) or e,out and palette.accent or palette.bad)
      end
    elseif p.id=="search" then query=prompt("Recherche",query)
    elseif p.revenue then revenueDetails(p.revenue.id) end
  end
end

local function expenseDetails(id,info)
  while true do
    local e,err=rpc("NC_EXPENSE_GET",{id=id})
    if not e then message("DEPENSE",err,palette.bad);return end
    info=rpc("NC_INFO",{}) or info or {}
    local finance=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local president=(info.nationalRole=="admin" or info.nationalRole=="president")
    local actions={{text="Lire la demande de depense",id="read"},{text="Imprimer la depense",id="print"}}
    if e.status=="requested" and finance then
      actions[#actions+1]={text="Valider par les Finances",id="finance_yes"}
      actions[#actions+1]={text="Rejeter par les Finances",id="finance_no"}
    elseif e.status=="finance_approved" and president then
      actions[#actions+1]={text="Autoriser par la Presidence",id="pres_yes"}
      actions[#actions+1]={text="Refuser par la Presidence",id="pres_no"}
    elseif e.status=="president_approved" and finance then
      actions[#actions+1]={text="Enregistrer le paiement",id="pay"}
    end
    local a=menu(e.id.." - "..e.title,actions,
      e.ministryCode.." / "..e.status.." / "..money(e.amountUB,"UB"))
    if not a then return end
    if a.id=="read" then
      textPage(e.id,{
        {label="Budget",text=e.budgetId or ""},{label="Ministere",text=e.ministryCode or ""},
        {label="Montant",text=money(e.amountUB,"UB")},{label="Objet",text=e.purpose or ""},
        {label="Base legale",text=e.legalBasis or "-"},{label="Prestataire",text=(e.vendorName or "-").." / "..(e.vendorId or "-")},
        {label="Controle renforce",text=e.requiresPresident and "Oui - validation presidentielle obligatoire" or "Non"},
        {label="Statut",text=e.status or ""},{label="Demandeur",text=e.requestedBy or ""},
        {label="Contrat",text=e.contractId or "-"},
        {label="Sceaux",text=(e.requestSeal or "-").."\n"..(e.financeSeal or "-").."\n"..(e.presidentSeal or "-").."\n"..(e.paymentSeal or e.decisionSeal or "-")}
      })
    elseif a.id=="print" then
      local ok,pages=printer.expense(e,"UB")
      message("IMPRESSION",ok and ("Depense imprimee: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="finance_yes" then
      local out,er=rpc("NC_EXPENSE_FINANCE_DECIDE",{id=e.id,approve=true})
      message("DEPENSE",out and ("Validation: "..out.status) or er,out and palette.accent or palette.bad)
    elseif a.id=="finance_no" then
      local reason=multi("MOTIF DU REJET","")
      local out,er=rpc("NC_EXPENSE_FINANCE_DECIDE",{id=e.id,approve=false,reason=reason})
      message("DEPENSE",out and "Depense rejetee." or er,out and palette.warn or palette.bad)
    elseif a.id=="pres_yes" then
      local out,er=rpc("NC_EXPENSE_PRESIDENT_DECIDE",{id=e.id,approve=true})
      message("DEPENSE",out and "Autorisation presidentielle accordee." or er,out and palette.accent or palette.bad)
    elseif a.id=="pres_no" then
      local reason=multi("MOTIF DU REFUS PRESIDENTIEL","")
      local out,er=rpc("NC_EXPENSE_PRESIDENT_DECIDE",{id=e.id,approve=false,reason=reason})
      message("DEPENSE",out and "Depense refusee." or er,out and palette.warn or palette.bad)
    elseif a.id=="pay" then
      local ref=prompt("Reference de paiement / note")
      local out,er=rpc("NC_EXPENSE_PAY",{id=e.id,paymentReference=ref})
      message("DEPENSE",out and ("Paiement enregistre / "..tostring(out.paymentSeal)) or er,out and palette.accent or palette.bad)
    end
  end
end

local function expensesScreen(info)
  local query,status="",""
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local rows,err=rpc("NC_EXPENSE_LIST",{query=query,status=status})
    if not rows then message("DEPENSES",err,palette.bad);return end
    local canRequest=(info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="minister")
    local items={}
    if canRequest then items[#items+1]={text="[+] Nouvelle demande de depense",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    for _,e in ipairs(rows) do items[#items+1]={text=e.id.." ["..e.status.."] "..e.ministryCode.." / "..money(e.amountUB,"UB").." / "..e.title,expense=e} end
    local p=menu("DEPENSES PUBLIQUES",items,#rows.." depense(s)")
    if not p then return end
    if p.id=="new" then
      local budgets=rpc("NC_BUDGET_LIST",{status="enacted"}) or {}
      local bi={};for _,b in ipairs(budgets) do bi[#bi+1]={text=b.id.." exercice "..b.fiscalYear.." / "..b.title,b=b} end
      local b=menu("BUDGET A IMPUTER",bi,#bi.." budget(s) actif(s)")
      if b then
        local ministryCode=info.nationalRole=="minister" and info.ministryCode or ""
        if ministryCode=="" then
          local ms=rpc("NC_MINISTRY_LIST",{}) or {}
          local mi={};for _,m in ipairs(ms) do mi[#mi+1]={text=m.code.." "..m.name,m=m} end
          local m=menu("MINISTERE DEPENSIER",mi);if not m then return end;ministryCode=m.m.code
        end
        local title=prompt("Titre de la depense")
        local amount=tonumber(prompt("Montant (UB)","0"))
        local legalBasis=prompt("Base legale NC-ART-... (optionnel)")
        local purpose=multi("OBJET / JUSTIFICATION DE LA DEPENSE","")
        local vendorType=menu("PRESTATAIRE",{{text="Organisation enregistree",v="organization"},{text="Autre / a definir",v="other"}})
        local vendorId,vendorName="",""
        if vendorType and vendorType.v=="organization" then
          local orgs=rpc("NC_ORG_LIST",{status="active"}) or {}
          local oi={};for _,o in ipairs(orgs) do oi[#oi+1]={text=o.id.." "..o.name,o=o} end
          local o=menu("PRESTATAIRE",oi,#oi.." organisation(s)")
          if o then vendorId=o.o.id;vendorName=o.o.name end
        else vendorName=prompt("Nom du prestataire / beneficiaire") end
        local out,e=rpc("NC_EXPENSE_REQUEST",{
          budgetId=b.b.id,ministryCode=ministryCode,title=title,amountUB=amount,
          legalBasis=legalBasis,purpose=purpose,vendorType=vendorType and vendorType.v or "other",
          vendorId=vendorId,vendorName=vendorName
        })
        message("DEPENSE",out and ("Demande: "..out.id..(out.requiresPresident and " / CONTROLE PRESIDENTIEL" or "")) or e,out and palette.accent or palette.bad)
      end
    elseif p.id=="search" then query=prompt("Recherche",query)
    elseif p.id=="status" then
      local st=menu("STATUT",{
        {text="Tous",v=""},{text="Demandees",v="requested"},{text="Validees finances",v="finance_approved"},
        {text="Autorisees",v="president_approved"},{text="Payees",v="paid"},{text="Rejetees",v="rejected"}
      })
      if st then status=st.v end
    elseif p.expense then expenseDetails(p.expense.id,info) end
  end
end

local function contractDetails(id,info)
  while true do
    local row,err=rpc("NC_CONTRACT_GET",{id=id})
    if not row then message("MARCHE PUBLIC",err,palette.bad);return end
    info=rpc("NC_INFO",{}) or info or {}
    local finance=(info.nationalRole=="admin" or info.nationalRole=="president" or
      (info.nationalRole=="minister" and info.ministryCode=="MIN-ECO"))
    local manager=finance or (info.nationalRole=="minister" and info.ministryCode==row.ministryCode)
    local actions={{text="Lire le marche",id="read"},{text="Imprimer le marche",id="print"}}
    if row.status=="draft" and finance then actions[#actions+1]={text="Attribuer officiellement le marche",id="award"}
    elseif (row.status=="awarded" or row.status=="active") and manager then actions[#actions+1]={text="Changer le statut d'execution",id="status"} end
    local a=menu(row.id.." - "..row.title,actions,row.ministryCode.." / "..row.status.." / "..money(row.amountUB,"UB"))
    if not a then return end
    if a.id=="read" then
      textPage(row.id,{
        {label="Ministere",text=row.ministryCode or ""},{label="Prestataire",text=(row.vendorName or "").." / "..(row.vendorOrgId or "")},
        {label="Depense associee",text=row.expenseId or ""},{label="Montant",text=money(row.amountUB,"UB")},
        {label="Objet",text=row.purpose or ""},{label="Procedure",text=row.procurementMethod or ""},
        {label="Justification",text=row.justification or "-"},{label="Statut",text=row.status or ""},
        {label="Sceaux",text=(row.draftSeal or "-").."\n"..(row.awardSeal or "-").."\n"..(row.closeSeal or "-")},
        {label="Journal officiel",text=row.gazetteId or "-"}
      })
    elseif a.id=="print" then
      local ok,pages=printer.contract(row,"UB")
      message("IMPRESSION",ok and ("Marche imprime: "..pages.." page(s).") or pages,ok and palette.accent or palette.bad)
    elseif a.id=="award" then
      local out,e=rpc("NC_CONTRACT_AWARD",{id=row.id})
      message("MARCHE PUBLIC",out and ("Attribue / "..tostring(out.awardSeal)) or e,out and palette.accent or palette.bad)
    elseif a.id=="status" then
      local opts={}
      if row.status=="awarded" then opts={{text="Demarrer l'execution",v="active"},{text="Resilier",v="terminated"}}
      else opts={{text="Achever le marche",v="completed"},{text="Resilier",v="terminated"}} end
      local st=menu("STATUT DU MARCHE",opts)
      if st then
        local reason=prompt("Note / motif")
        local out,e=rpc("NC_CONTRACT_SET_STATUS",{id=row.id,status=st.v,reason=reason})
        message("MARCHE PUBLIC",out and ("Statut: "..out.status) or e,out and palette.accent or palette.bad)
      end
    end
  end
end

local function contractsScreen(info)
  local query=""
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local rows,err=rpc("NC_CONTRACT_LIST",{query=query})
    if not rows then message("MARCHES PUBLICS",err,palette.bad);return end
    local canCreate=(info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="minister")
    local items={}
    if canCreate then items[#items+1]={text="[+] Preparer un marche public",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    for _,x in ipairs(rows) do items[#items+1]={text=x.id.." ["..x.status.."] "..x.ministryCode.." / "..x.vendorName.." / "..x.title,contract=x} end
    local p=menu("MARCHES PUBLICS",items,#rows.." marche(s)")
    if not p then return end
    if p.id=="new" then
      local ministryCode=info.nationalRole=="minister" and info.ministryCode or ""
      if ministryCode=="" then
        local ms=rpc("NC_MINISTRY_LIST",{}) or {}
        local mi={};for _,m in ipairs(ms) do mi[#mi+1]={text=m.code.." "..m.name,m=m} end
        local m=menu("MINISTERE",mi);if not m then return end;ministryCode=m.m.code
      end
      local expenses=rpc("NC_EXPENSE_LIST",{ministryCode=ministryCode}) or {}
      local ei={}
      for _,e in ipairs(expenses) do
        if e.status=="finance_approved" or e.status=="president_approved" then
          ei[#ei+1]={text=e.id.." ["..e.status.."] "..money(e.amountUB,"UB").." / "..e.title,e=e}
        end
      end
      local ex=menu("DEPENSE AUTORISEE",ei,#ei.." depense(s)")
      if ex then
        local orgs=rpc("NC_ORG_LIST",{status="active"}) or {}
        local oi={};for _,o in ipairs(orgs) do oi[#oi+1]={text=o.id.." "..o.name,o=o} end
        local org=menu("PRESTATAIRE",oi,#oi.." organisation(s)")
        if org then
          local method=menu("PROCEDURE",{
            {text="Appel d'offres ouvert",v="open_tender"},{text="Appel restreint",v="restricted_tender"},
            {text="Attribution directe",v="direct"},{text="Urgence",v="emergency"}
          })
          if method then
            local title=prompt("Titre du marche")
            local purpose=multi("OBJET DU MARCHE","")
            local justification=(method.v=="direct" or method.v=="emergency") and multi("JUSTIFICATION DE LA PROCEDURE","") or ""
            local out,e=rpc("NC_CONTRACT_CREATE",{
              ministryCode=ministryCode,expenseId=ex.e.id,vendorOrgId=org.o.id,
              procurementMethod=method.v,title=title,purpose=purpose,justification=justification
            })
            message("MARCHE PUBLIC",out and ("Prepare: "..out.id) or e,out and palette.accent or palette.bad)
          end
        end
      end
    elseif p.id=="search" then query=prompt("Recherche",query)
    elseif p.contract then contractDetails(p.contract.id,info) end
  end
end

local function financeScreen(info)
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local d,err=rpc("NC_TREASURY_DASHBOARD",{})
    if not d then message("FINANCES",err,palette.bad);return end
    local items={
      {text="BUDGETS / CREDITS MINISTERIELS",id="budgets"},
      {text="RECETTES / TRESORERIE",id="revenues"},
      {text="DEPENSES / ENGAGEMENTS / PAIEMENTS",id="expenses"},
      {text="MARCHES PUBLICS / PRESTATAIRES",id="contracts"}
    }
    local p=menu("FINANCES PUBLIQUES",items,
      "Solde "..money(d.balanceUB,d.unit).." / recettes "..money(d.revenueUB,d.unit)..
      " / depenses "..money(d.spentUB,d.unit).." / budget "..tostring(d.currentBudgetId or "aucun"))
    if not p then return end
    if p.id=="budgets" then budgetsScreen(info)
    elseif p.id=="revenues" then revenuesScreen(info)
    elseif p.id=="expenses" then expensesScreen(info)
    elseif p.id=="contracts" then contractsScreen(info) end
  end
end

local function nationalNotices(info)
  while true do
    local rows,err=rpc("NC_NOTICE_LIST",{})
    if not rows then message("NOTIFICATIONS NC",err,palette.bad);return end
    local items={{text="[✓] Marquer toutes comme lues",id="all"}}
    for _,n in ipairs(rows) do
      items[#items+1]={
        text=(n.read and "    " or "[!] ")..(n.title or "Notification").." / "..(n.createdAt or ""),
        notice=n
      }
    end
    local p=menu("NOTIFICATIONS NORTH COALITION",items,#rows.." notification(s)")
    if not p then return end
    if p.id=="all" then
      local count=0
      for _,n in ipairs(rows) do
        if not n.read then
          local ok=rpc("NOTICE_MARK_READ",{id=n.id})
          if ok then count=count+1 end
        end
      end
      message("NOTIFICATIONS",tostring(count).." notification(s) marquee(s) comme lue(s).",palette.accent)
    elseif p.notice then
      local n=p.notice
      if not n.read then rpc("NOTICE_MARK_READ",{id=n.id}) end
      local actions={{text="Lire la notification",id="read"}}
      if n.objectType=="nc_election" then actions[#actions+1]={text="Ouvrir le scrutin",id="open"}
      elseif n.objectType=="nc_general_election" then actions[#actions+1]={text="Ouvrir l'election nationale",id="open"}
      elseif n.objectType=="nc_bill" then actions[#actions+1]={text="Ouvrir le projet de loi",id="open"}
      elseif n.objectType=="nc_decree" then actions[#actions+1]={text="Ouvrir le decret",id="open"}
      elseif n.objectType=="nc_ministry" then actions[#actions+1]={text="Ouvrir le ministere",id="open"}
      elseif n.objectType=="nc_government" then actions[#actions+1]={text="Ouvrir le Gouvernement",id="open"}
      elseif n.objectType=="nc_case" then actions[#actions+1]={text="Ouvrir le dossier judiciaire",id="open"}
      elseif n.objectType=="nc_citizen" then actions[#actions+1]={text="Ouvrir la fiche citoyenne",id="open"}
      elseif n.objectType=="nc_session" then actions[#actions+1]={text="Ouvrir la session",id="open"}
      elseif n.objectType=="nc_license" then actions[#actions+1]={text="Ouvrir la licence",id="open"}
      elseif n.objectType=="nc_fine" then actions[#actions+1]={text="Ouvrir l'amende",id="open"}
      elseif n.objectType=="nc_request" then actions[#actions+1]={text="Ouvrir la demande",id="open"}
      elseif n.objectType=="nc_budget" then actions[#actions+1]={text="Ouvrir le budget",id="open"}
      elseif n.objectType=="nc_expense" then actions[#actions+1]={text="Ouvrir la depense",id="open"}
      elseif n.objectType=="nc_contract" then actions[#actions+1]={text="Ouvrir le marche public",id="open"} end
      local a=menu(n.title or n.id,actions,(n.severity or "info").." / "..(n.createdAt or ""))
      if a and a.id=="read" then
        textPage(n.id,{
          {label="Notification",text=n.title or ""},
          {label="Date",text=n.createdAt or ""},
          {label="Niveau",text=n.severity or "info"},
          {label="Message",text=n.body or ""},
          {label="Objet",text=(n.objectType or "-").." / "..(n.objectId or "-")}
        })
      elseif a and a.id=="open" then
        if n.objectType=="nc_election" then C.electionDetails(n.objectId)
        elseif n.objectType=="nc_general_election" then dofile("/international_code/national_democracy_client.lua").openElection(n.objectId)
        elseif n.objectType=="nc_bill" then billDetails(n.objectId)
        elseif n.objectType=="nc_decree" then decreeDetails(n.objectId)
        elseif n.objectType=="nc_ministry" then ministryDetails(n.objectId)
        elseif n.objectType=="nc_government" then governmentScreen(info)
        elseif n.objectType=="nc_case" then caseDetails(n.objectId)
        elseif n.objectType=="nc_citizen" then citizenDetails(n.objectId,info)
        elseif n.objectType=="nc_session" then sessionDetails(n.objectId,info)
        elseif n.objectType=="nc_license" then licenseDetails(n.objectId,info)
        elseif n.objectType=="nc_fine" then fineDetails(n.objectId,info)
        elseif n.objectType=="nc_request" then requestDetails(n.objectId,info)
        elseif n.objectType=="nc_budget" then budgetDetails(n.objectId,info)
        elseif n.objectType=="nc_expense" then expenseDetails(n.objectId,info)
        elseif n.objectType=="nc_contract" then contractDetails(n.objectId,info) end
      end
    end
  end
end

local function auditScreen()
  local rows,err=rpc("NC_AUDIT_LIST",{limit=150})
  if not rows then message("AUDIT NATIONAL",err,palette.bad);return end
  local lines={}
  for _,r in ipairs(rows) do lines[#lines+1]=(r.at or "").." / "..(r.actor or "").." / "..(r.action or "").." / "..(r.objectId or "").."\n"..(r.details or "") end
  textPage("JOURNAL NATIONAL",{{label="Dernieres operations",text=table.concat(lines,"\n\n")}})
end


local function portalMySpace(info,dash)
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local items={}
    if info.citizenId then
      items[#items+1]={text="MA FICHE CITOYENNE / "..tostring(info.citizenId),id="citizen"}
      items[#items+1]={text="MON DOSSIER INDIVIDUEL / LICENCES / AMENDES",id="record"}
    else
      items[#items+1]={text="[!] AUCUNE IDENTITE CITOYENNE RATTACHEE",id="noidentity"}
    end
    items[#items+1]={text="MES DEMANDES / GUICHET ADMINISTRATIF",id="requests"}
    items[#items+1]={text="NOTIFICATIONS NATIONALES"..(((dash and dash.unreadNotices) or 0)>0 and (" ("..tostring(dash.unreadNotices)..")") or ""),id="notices"}
    items[#items+1]={text="ELECTIONS NATIONALES / CANDIDATURE / VOTE",id="democracy"}
    items[#items+1]={text="CONSULTER LE CODE NATIONAL",id="code"}
    local p=menu("MON ESPACE NORTH COALITION",items,
      roleLabel(info.nationalRole).." / "..tostring(info.nationalIdentity or "-")..
      (info.ministryCode and (" / "..info.ministryCode) or ""))
    if not p then return end
    if p.id=="citizen" then citizenDetails(info.citizenId,info)
    elseif p.id=="record" then citizenRecordScreen(info)
    elseif p.id=="requests" then requestsScreen(info)
    elseif p.id=="notices" then nationalNotices(info)
    elseif p.id=="democracy" then dofile("/international_code/national_democracy_client.lua").run()
    elseif p.id=="code" then codeScreen()
    elseif p.id=="noidentity" then
      message("IDENTITE NATIONALE","Ce terminal doit etre rattache a une fiche NC-CIT par l'administration competente.",palette.warn)
    end
  end
end

local function portalLawHub(info,dash)
  while true do
    local items={
      {text="CODE NATIONAL / 20 CATEGORIES / RECHERCHE",id="code"},
      {text="LEGISLATION / PROJETS DE LOI / VOTES",id="bills"},
      {text="DECRETS / REGLEMENTS",id="decrees"},
      {text="JOURNAL OFFICIEL / PUBLICATIONS",id="gazette"},
      {text="VERIFIER UN SCEAU OFFICIEL NORTH COALITION",id="verify"}
    }
    local p=menu("DROIT ET PUBLICATIONS",items,
      tostring((dash and dash.activeLaws) or 0).." loi(s) en vigueur / "..
      tostring((dash and dash.votingBills) or 0).." projet(s) en vote")
    if not p then return end
    if p.id=="code" then codeScreen()
    elseif p.id=="bills" then billsScreen()
    elseif p.id=="decrees" then decreesScreen(info)
    elseif p.id=="gazette" then gazetteScreen(info)
    elseif p.id=="verify" then verifyNationalSealScreen("") end
  end
end

local function portalInstitutionsHub(info,dash)
  while true do
    local items={
      {text="GOUVERNEMENT / PRESIDENCE / MINISTERES",id="gov"},
      {text="DEMOCRATIE NATIONALE / PRESIDENCE / CONSEIL",id="democracy"},
      {text="SCRUTINS MINISTERIELS",id="elections"},
      {text="SESSIONS / CONSEIL / CABINET / ORDRE DU JOUR",id="sessions"},
      {text="JOURNAL OFFICIEL INSTITUTIONNEL",id="gazette"}
    }
    local p=menu("INSTITUTIONS NATIONALES",items,
      "President: "..tostring((dash and dash.presidentIdentity) or "-")..
      " / "..tostring((dash and dash.filledMinistries) or 0).."/"..tostring((dash and dash.ministries) or 0).." ministere(s)")
    if not p then return end
    if p.id=="gov" then governmentScreen(info)
    elseif p.id=="democracy" then dofile("/international_code/national_democracy_client.lua").run()
    elseif p.id=="elections" then C.electionsScreen()
    elseif p.id=="sessions" then sessionsScreen(info)
    elseif p.id=="gazette" then gazetteScreen(info) end
  end
end

local function portalServicesHub(info,dash)
  while true do
    local items={
      {text="GUICHET CITOYEN / DEMANDES",id="requests"},
      {text="REGISTRE CIVIL / CITOYENS / IDENTITES",id="citizens"},
      {text="ORGANISATIONS / ENTREPRISES / ASSOCIATIONS",id="orgs"},
      {text="LICENCES / AUTORISATIONS / PERMIS",id="licenses"},
      {text="AMENDES / SANCTIONS PECUNIAIRES",id="fines"},
      {text="DOSSIER INDIVIDUEL",id="record"}
    }
    local p=menu("SERVICES PUBLICS",items,
      tostring((dash and dash.pendingRequests) or 0).." demande(s) en cours / "..
      tostring((dash and dash.activeCitizens) or 0).." citoyen(s)")
    if not p then return end
    if p.id=="requests" then requestsScreen(info)
    elseif p.id=="citizens" then citizensScreen(info)
    elseif p.id=="orgs" then organizationsScreen(info)
    elseif p.id=="licenses" then licensesScreen(info)
    elseif p.id=="fines" then finesScreen(info)
    elseif p.id=="record" then citizenRecordScreen(info) end
  end
end

local function portalJusticeHub(info,dash)
  while true do
    local items={
      {text="JUSTICE / DOSSIERS NATIONAUX",id="cases"},
      {text="AMENDES / CONTESTATIONS / DECISIONS",id="fines"},
      {text="DOSSIER INDIVIDUEL / SYNTHESE",id="record"},
      {text="CODE NATIONAL / RECHERCHE JURIDIQUE",id="code"},
      {text="VERIFIER UN SCEAU / ACTE / PREUVE",id="verify"}
    }
    local p=menu("JUSTICE ET SECURITE",items,
      tostring((dash and dash.openCases) or 0).." dossier(s) judiciaire(s) ouvert(s)")
    if not p then return end
    if p.id=="cases" then casesScreen()
    elseif p.id=="fines" then finesScreen(info)
    elseif p.id=="record" then citizenRecordScreen(info)
    elseif p.id=="code" then codeScreen()
    elseif p.id=="verify" then verifyNationalSealScreen("") end
  end
end

local function portalEconomyHub(info,dash)
  while true do
    local items={
      {text="FINANCES PUBLIQUES / TRESORERIE / BUDGET",id="finance"},
      {text="ORGANISATIONS / ENTREPRISES / BANQUES",id="orgs"},
      {text="LICENCES ECONOMIQUES ET PROFESSIONNELLES",id="licenses"},
      {text="JOURNAL OFFICIEL / MARCHES ET ACTES",id="gazette"}
    }
    local p=menu("ECONOMIE ET FINANCES",items,
      "Tresorerie: "..money((dash and dash.treasuryBalanceUB) or 0,(dash and dash.treasuryUnit) or "UB")..
      " / budget "..tostring((dash and dash.currentBudgetId) or "aucun"))
    if not p then return end
    if p.id=="finance" then financeScreen(info)
    elseif p.id=="orgs" then organizationsScreen(info)
    elseif p.id=="licenses" then licensesScreen(info)
    elseif p.id=="gazette" then gazetteScreen(info) end
  end
end

local function portalInternalHub(info,dash)
  while true do
    info=rpc("NC_INFO",{}) or info or {}
    local items={
      {text="ADMINISTRATION NATIONALE COMPLETE",id="adminservices"},
      {text="GOUVERNEMENT / GESTION DES FONCTIONS",id="gov"},
      {text="REGISTRE CIVIL / TERMINAUX / IDENTITES",id="citizens"},
      {text="SESSIONS INSTITUTIONNELLES",id="sessions"}
    }
    if info.nationalRole=="admin" or info.nationalRole=="president" or info.nationalRole=="council" or info.nationalRole=="judge" then
      items[#items+1]={text="JOURNAL D'AUDIT NATIONAL",id="audit"}
    end
    local p=menu("RESEAU INTERNE / ACCES RESTREINT",items,
      "Habilitation: "..roleLabel(info.nationalRole)..(info.ministryCode and (" / "..info.ministryCode) or ""))
    if not p then return end
    if p.id=="adminservices" then administrationScreen(info)
    elseif p.id=="gov" then governmentScreen(info)
    elseif p.id=="citizens" then citizensScreen(info)
    elseif p.id=="sessions" then sessionsScreen(info)
    elseif p.id=="audit" then auditScreen() end
  end
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
      " | "..tostring(dash.unreadNotices or 0).." notif. / "..
      tostring(dash.pendingRequests or 0).." demande(s) / "..
      tostring(dash.openCases or 0).." dossier(s)"

    local items={}
    if (dash.unreadNotices or 0)>0 then
      items[#items+1]={text="[!] NOTIFICATIONS PRIORITAIRES ("..tostring(dash.unreadNotices)..")",id="notices"}
    end
    items[#items+1]={text="MON ESPACE / IDENTITE / DEMANDES / VOTE",id="my"}
    items[#items+1]={text="DROIT / CODE NATIONAL / JOURNAL OFFICIEL",id="law"}
    items[#items+1]={text="INSTITUTIONS / GOUVERNEMENT / ELECTIONS",id="institutions"}
    items[#items+1]={text="SERVICES PUBLICS / GUICHET / REGISTRES",id="services"}
    items[#items+1]={text="JUSTICE / SECURITE / DOSSIERS",id="justice"}
    items[#items+1]={text="ECONOMIE / FINANCES / ORGANISATIONS",id="economy"}

    local restricted=(dash.nationalRole=="admin" or dash.nationalRole=="president" or
      dash.nationalRole=="council" or dash.nationalRole=="minister" or
      dash.nationalRole=="judge" or dash.nationalRole=="prosecutor" or
      dash.nationalRole=="police" or dash.nationalRole=="civil_servant")
    if restricted then
      items[#items+1]={text="RESEAU INTERNE / OUTILS INSTITUTIONNELS",id="internal"}
    end

    items[#items+1]={text="RETOUR A L'UNION DES NATIONS SOUVERAINES",id="back"}

    local p=menu("PORTAIL NATIONAL NORTH COALITION",items,subtitle)
    if not p or p.id=="back" then clear();return end
    if p.id=="notices" then nationalNotices(info)
    elseif p.id=="my" then portalMySpace(info,dash)
    elseif p.id=="law" then portalLawHub(info,dash)
    elseif p.id=="institutions" then portalInstitutionsHub(info,dash)
    elseif p.id=="services" then portalServicesHub(info,dash)
    elseif p.id=="justice" then portalJusticeHub(info,dash)
    elseif p.id=="economy" then portalEconomyHub(info,dash)
    elseif p.id=="internal" then portalInternalHub(info,dash) end
  end
end

function C.verify(sealValue)
  cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client requis.",0) end
  common.openModems()
  sealValue=common.trim(sealValue or "")
  if sealValue=="" then error("Usage: ic nc-verify <SCEAU>",0) end
  local out,err=rpc("NC_VERIFY_SEAL",{seal=sealValue})
  if not out then error(err,0) end
  if not out.valid then
    print("SCEAU NATIONAL INVALIDE: "..sealValue)
    return false
  end
  print("SCEAU NATIONAL VALIDE")
  print("Type: "..tostring(out.kind or "?"))
  print("Objet: "..tostring(out.objectId or "?"))
  print("Titre: "..tostring(out.title or "?"))
  if not out.confidential then
    print("Date: "..tostring(out.issuedAt or "?"))
    print("Autorite: "..tostring(out.issuedBy or "?"))
  else
    print("Contenu: RESTREINT")
  end
  return true
end

return C
