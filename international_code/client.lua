local common = dofile("/international_code/common.lua")
local printer = dofile("/international_code/printer.lua")
local C = {}

local palette={
  bg=colors.black,panel=colors.gray,header=colors.blue,accent=colors.cyan,
  text=colors.white,muted=colors.lightGray,ok=colors.lime,warn=colors.yellow,bad=colors.red
}
local cfg=nil

local function clear(bg)
  term.setBackgroundColor(bg or palette.bg)
  term.setTextColor(palette.text)
  term.clear()
  term.setCursorPos(1,1)
end

local function at(x,y,text,fg,bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(math.max(1,x),math.max(1,y))
  term.write(tostring(text or ""))
end

local function bar(title,subtitle)
  local w=term.getSize()
  term.setBackgroundColor(palette.header)
  term.setTextColor(palette.text)
  term.setCursorPos(1,1)
  term.clearLine()
  term.write(common.fit(" UNS / "..title,w))
  if subtitle then
    term.setBackgroundColor(palette.bg)
    at(2,2,common.fit(subtitle,math.max(1,w-3)),palette.muted)
  end
end

local function footer(text)
  local w,h=term.getSize()
  term.setBackgroundColor(palette.bg)
  at(1,h,common.fit(text,w),palette.muted)
end

local function wait(msg)
  footer(msg or "Appuyez sur une touche...")
  os.pullEvent("key")
end

local function message(title,text,color)
  clear()
  bar(title)
  at(2,4,text,color or palette.text)
  wait()
end

local function rpc(action,payload,timeout)
  cfg=cfg or common.loadConfig()
  if not cfg or not cfg.serverId then return nil,"Terminal non appaire." end
  common.openModems()
  local rid=tostring(os.getComputerID()).."-"..tostring(common.nowMs()).."-"..common.randomToken(5)
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
    elseif ev=="timer" and a==timer then
      return nil,"Serveur injoignable (timeout)."
    end
  end
end

local function prompt(label,default)
  local w,h=term.getSize()
  term.setBackgroundColor(palette.bg)
  term.setTextColor(palette.text)
  term.setCursorPos(2,h-2)
  term.clearLine()
  term.write(label..(default and default~="" and " ["..default.."]" or "")..": ")
  local v=read()
  if v=="" and default then return default end
  return v
end

local referenceBrowser

local function multi(label,initial)
  common.ensureLayout()
  local draftsDir = common.ROOT .. "/drafts"
  if not fs.exists(draftsDir) then fs.makeDir(draftsDir) end

  local path = draftsDir .. "/draft-" .. os.getComputerID() .. "-" .. common.randomToken(6) .. ".txt"
  local h = assert(fs.open(path, "w"))
  h.write(initial or "")
  h.close()

  local firstOpen = true
  while true do
    clear()
    bar(label, firstOpen
      and "Votre brouillon reste sauvegarde pendant toute la consultation du Code."
      or "Brouillon conserve. Reprenez, consultez le Code ou terminez.")
    at(2,4,"Fichier de travail: "..path,palette.muted)
    at(2,6,"L'editeur CraftOS va s'ouvrir.",palette.text)
    at(2,7,"Enregistrez puis quittez-le pour revenir au bureau de redaction.",palette.muted)
    sleep(0.35)

    local ok = shell.run("edit", path)
    if not ok then
      message("EDITEUR", "L'editeur CraftOS a signale une erreur. Le brouillon est toujours conserve.", palette.warn)
    end
    firstOpen = false

    local desk = menu("BUREAU DE REDACTION",{
      {text="Reprendre l'ecriture",id="resume"},
      {text="Consulter le Code par categories",id="browse"},
      {text="Rechercher un article dans le Code",id="search"},
      {text="Inserer une reference d'article a la fin du brouillon",id="insert"},
      {text="Terminer et utiliser ce texte",id="finish"},
      {text="Abandonner cette modification et conserver le brouillon sur le PC",id="keep"}
    },"Le texte n'est jamais efface lorsque vous consultez les lois.")

    if not desk or desk.id=="resume" then
      -- Reouvre simplement le meme fichier : aucun texte n'est perdu.
    elseif desk.id=="browse" then
      if referenceBrowser then referenceBrowser({mode="browse",readonly=true}) end
    elseif desk.id=="search" then
      if referenceBrowser then referenceBrowser({mode="search",readonly=true}) end
    elseif desk.id=="insert" then
      local law = referenceBrowser and referenceBrowser({mode="browse",pick=true,readonly=true}) or nil
      if law then
        local current = common.readAll(path) or ""
        local suffix = ""
        if current ~= "" and not current:match("\n$") then suffix="\n" end
        local out = assert(fs.open(path,"a"))
        out.write(suffix.."["..law.ref.."] "..law.title.."\n")
        out.close()
        message("REFERENCE AJOUTEE",law.ref.." a ete ajoute au brouillon.",palette.ok)
      end
    elseif desk.id=="finish" then
      local text = common.readAll(path) or ""
      if fs.exists(path) then fs.delete(path) end
      return text
    elseif desk.id=="keep" then
      local text = common.readAll(path) or ""
      message("BROUILLON CONSERVE","Le brouillon reste sur ce PC : "..path,palette.warn)
      return text
    end
  end
end

local function menu(title,items,subtitle)
  local selected=1
  local offset=0
  while true do
    clear()
    bar(title,subtitle)
    local w,h=term.getSize()
    local top=4
    local visible=math.max(3,h-top-2)

    if selected<1 then selected=1 end
    if selected>#items then selected=#items end
    if selected<1 then return nil end

    if selected-offset>visible then offset=selected-visible end
    if selected<=offset then offset=selected-1 end

    for row=1,visible do
      local idx=offset+row
      if idx>#items then break end
      local item=items[idx]
      local text=type(item)=="table" and (item.text or item.label or tostring(idx)) or tostring(item)
      if idx==selected then
        term.setBackgroundColor(palette.panel)
        term.setTextColor(palette.text)
      else
        term.setBackgroundColor(palette.bg)
        term.setTextColor(palette.muted)
      end
      at(2,top+row-1,common.fit((idx==selected and "> " or "  ")..text,math.max(1,w-3)))
    end

    term.setBackgroundColor(palette.bg)
    footer("Fleches/roulette: naviguer  Entree: ouvrir  Retour: precedent")

    local ev,a,b,c=os.pullEvent()
    if ev=="key" then
      if a==keys.up then
        selected=math.max(1,selected-1)
      elseif a==keys.down then
        selected=math.min(#items,selected+1)
      elseif a==keys.enter then
        return items[selected],selected
      elseif a==keys.backspace or a==keys.left then
        return nil
      end
    elseif ev=="mouse_scroll" then
      selected=math.max(1,math.min(#items,selected+a))
    elseif ev=="mouse_click" then
      local row=c-top+1
      local idx=offset+row
      if row>=1 and row<=visible and idx>=1 and idx<=#items then
        if selected==idx then return items[idx],idx else selected=idx end
      end
    end
  end
end

local function textPage(title,sections)
  local all={}
  local w,h=term.getSize()
  local bodyWidth=math.max(10,w-4)

  for _,s in ipairs(sections) do
    if s.label then all[#all+1]=s.label end
    for _,l in ipairs(common.wrap(s.text or "",bodyWidth)) do all[#all+1]=l end
    all[#all+1]=""
  end

  local page=1
  while true do
    clear()
    bar(title)
    w,h=term.getSize()
    local per=math.max(4,h-4)
    local start=(page-1)*per+1
    local pages=math.max(1,math.ceil(#all/per))
    for i=0,per-1 do
      if all[start+i] then
        at(2,3+i,common.fit(all[start+i],math.max(1,w-3)),palette.text)
      end
    end
    footer("Page "..page.."/"..pages.."  <- -> pages  Retour")
    local _,k=os.pullEvent("key")
    if k==keys.right or k==keys.pageDown then
      page=math.min(pages,page+1)
    elseif k==keys.left or k==keys.pageUp then
      page=math.max(1,page-1)
    elseif k==keys.backspace or k==keys.enter then
      return
    end
  end
end


local function lawQuickView(law)
  if not law then return end
  local full,err=rpc("LAW_GET",{ref=law.ref})
  if not full then message("ARTICLE",err,palette.bad);return end
  textPage(full.ref,{
    {label=full.title,text=full.body},
    {label="Classement",text=(full.book or "").." / "..(full.section or "")},
    {label="Statut",text=(full.status or "?").." / version "..tostring(full.version or 1)}
  })
end

local function collectBooks(laws)
  local books={}
  local order={}
  for _,law in ipairs(laws or {}) do
    local name=(law.book and law.book~="") and law.book or "SANS CATEGORIE"
    if not books[name] then
      books[name]={name=name,laws={},first=law.number or 999999}
      order[#order+1]=books[name]
    end
    books[name].laws[#books[name].laws+1]=law
    if (law.number or 999999)<books[name].first then books[name].first=law.number end
  end
  table.sort(order,function(a,b) return a.first<b.first end)
  return order
end

local function chooseLawFromList(title,laws,opts)
  opts=opts or {}
  if not laws or #laws==0 then
    message("CODE","Aucun article dans cette selection.",palette.warn)
    return nil
  end

  while true do
    local items={}
    for _,law in ipairs(laws) do
      items[#items+1]={
        text=law.ref.."  "..law.title.."  ["..(law.status or "?").."]",
        law=law
      }
    end

    local p=menu(title,items,#laws.." article(s) - Entree pour ouvrir")
    if not p then return nil end
    local law=p.law
    if opts.pick then
      local action=menu(law.ref.." - "..law.title,{
        {text="Lire l'article",id="read"},
        {text="Choisir cette reference",id="pick"}
      },"Vous pouvez lire avant de l'utiliser.")
      if action and action.id=="read" then
        lawQuickView(law)
      elseif action and action.id=="pick" then
        return law
      end
    elseif opts.manage then
      return law
    else
      lawQuickView(law)
    end
  end
end

referenceBrowser=function(opts)
  opts=opts or {}
  while true do
    local all,err=rpc("LAW_LIST",{query=""})
    if not all then message("CODE",err,palette.bad);return nil end

    if opts.mode=="search" then
      local q=prompt("Recherche article / mot / numero")
      if q=="" then return nil end
      local found,e=rpc("LAW_LIST",{query=q})
      if not found then message("RECHERCHE",e,palette.bad);return nil end
      local chosen=chooseLawFromList("RESULTATS: "..q,found,opts)
      if chosen or opts.pick then return chosen end
      opts.mode="browse"
    else
      local books=collectBooks(all)
      local items={
        {text="[?] Rechercher dans les 500+ articles",id="search"},
        {text="[*] Parcourir tous les articles",id="all"}
      }
      for _,book in ipairs(books) do
        items[#items+1]={
          text=book.name.."  ("..#book.laws..")",
          book=book
        }
      end

      local p=menu("BIBLIOTHEQUE DU CODE",items,#all.." articles / "..#books.." categories")
      if not p then return nil end

      if p.id=="search" then
        local q=prompt("Recherche article / mot / numero")
        if q~="" then
          local found,e=rpc("LAW_LIST",{query=q})
          if not found then
            message("RECHERCHE",e,palette.bad)
          else
            local chosen=chooseLawFromList("RESULTATS: "..q,found,opts)
            if chosen then return chosen end
          end
        end
      elseif p.id=="all" then
        local chosen=chooseLawFromList("TOUS LES ARTICLES",all,opts)
        if chosen then return chosen end
      elseif p.book then
        local chosen=chooseLawFromList(p.book.name,p.book.laws,opts)
        if chosen then return chosen end
      end
    end
  end
end

local roleAllows={
  lawWrite={writer=true,admin=true},
  caseWrite={clerk=true,judge=true,admin=true},
  judgment={judge=true,admin=true},
  audit={writer=true,clerk=true,judge=true,admin=true}
}

local function allowed(group)
  return cfg and roleAllows[group] and roleAllows[group][cfg.role]
end

local function viewLaw(ref)
  while true do
    local law,err=rpc("LAW_GET",{ref=ref})
    if not law then message("ARTICLE",err,palette.bad);return end

    local actions={
      {text="Lire le texte",id="read"},
      {text="Imprimer l'article",id="print"}
    }
    if allowed("lawWrite") then
      actions[#actions+1]={text="Modifier / nouvelle version",id="amend"}
      actions[#actions+1]={text="Changer le statut",id="status"}
      actions[#actions+1]={text="Abroger",id="repeal"}
    end

    local a=menu(
      law.ref.." - "..law.title,
      actions,
      "Statut: "..law.status.." / version "..law.version.." / "..(law.book or "")
    )
    if not a then return end

    if a.id=="read" then
      textPage(law.ref,{
        {label=law.title,text=law.body},
        {label="Classement",text=(law.book or "").." / "..(law.section or "")},
        {label="Statut",text=law.status.." / v"..law.version}
      })

    elseif a.id=="print" then
      local ok,r=printer.law(law)
      message("IMPRESSION",ok and ("Impression lancee: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

    elseif a.id=="amend" then
      local title=prompt("Nouveau titre (Entree = conserver)",law.title)
      local body=multi("NOUVELLE VERSION",law.body)
      local updated,e=rpc("LAW_AMEND",{
        ref=law.ref,title=title,body=body,book=law.book,section=law.section
      })
      message("ARTICLE",updated and (law.ref.." passe en version "..updated.version) or e,updated and palette.ok or palette.bad)

    elseif a.id=="status" then
      local choice=menu("STATUT",{
        {text="Brouillon",v="draft"},
        {text="Actif / ratifie",v="active"},
        {text="Suspendu",v="suspended"},
        {text="Abroge",v="repealed"}
      })
      if choice then
        local r,e=rpc("LAW_SET_STATUS",{ref=law.ref,status=choice.v})
        message("STATUT",r and ("Nouveau statut: "..r.status) or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="repeal" then
      local reason=multi("MOTIF D'ABROGATION","")
      local r,e=rpc("LAW_REPEAL",{ref=law.ref,reason=reason})
      message("ABROGATION",r and "Article abroge. Son numero reste reserve." or e,r and palette.ok or palette.bad)
    end
  end
end

local function lawsScreen(query)
  while true do
    local items={}
    if allowed("lawWrite") then
      items[#items+1]={text="[+] Creer un nouvel article",id="new"}
    end
    items[#items+1]={text="[L] Parcourir par LIVRE / categorie",id="books"}
    items[#items+1]={text="[?] Rechercher par numero, titre ou mot",id="search"}
    items[#items+1]={text="[*] Afficher tous les articles",id="all"}

    local pick=menu("CODE INTERNATIONAL",items,"Navigation par categories + recherche instantanee")
    if not pick then return end

    if pick.id=="new" then
      local title=prompt("Titre")
      local all=rpc("LAW_LIST",{query=""}) or {}
      local books=collectBooks(all)
      local bookItems={}
      for _,b in ipairs(books) do bookItems[#bookItems+1]={text=b.name,book=b.name} end
      bookItems[#bookItems+1]={text="[NOUVELLE CATEGORIE]",book="__new"}
      local bp=menu("CATEGORIE / LIVRE",bookItems,"Choisissez le Livre de classement")
      local book=""
      if bp then
        if bp.book=="__new" then book=prompt("Nom du nouveau Livre / categorie")
        else book=bp.book end
      end
      local section=prompt("Titre / section (optionnel)")
      local body=multi("TEXTE DE L'ARTICLE","")
      local r,e=rpc("LAW_CREATE",{title=title,book=book,section=section,body=body,status="draft"})
      message("CREATION",r and ("Cree: "..r.ref) or e,r and palette.ok or palette.bad)

    elseif pick.id=="books" then
      while true do
        local law=referenceBrowser({mode="browse",manage=true})
        if not law then break end
        viewLaw(law.ref)
      end

    elseif pick.id=="search" then
      while true do
        local q=prompt("Recherche",query or "")
        if q=="" then break end
        query=q
        local laws,err=rpc("LAW_LIST",{query=q})
        if not laws then
          message("CODE",err,palette.bad)
          break
        end
        local law=chooseLawFromList("RESULTATS: "..q,laws,{manage=true})
        if law then viewLaw(law.ref) else break end
      end

    elseif pick.id=="all" then
      local laws,err=rpc("LAW_LIST",{query=""})
      if not laws then message("CODE",err,palette.bad)
      else
        while true do
          local law=chooseLawFromList("TOUS LES ARTICLES",laws,{manage=true})
          if not law then break end
          viewLaw(law.ref)
        end
      end
    end
  end
end

local function caseDetails(id)
  while true do
    local c,err=rpc("CASE_GET",{id=id})
    if not c then message("DOSSIER",err,palette.bad);return end

    local actions={
      {text="Lire le dossier complet",id="read"},
      {text="Imprimer le dossier",id="print"}
    }

    if allowed("caseWrite") then
      actions[#actions+1]={text="Ajouter un fait",id="fact"}
      actions[#actions+1]={text="Ajouter une preuve",id="evidence"}
      actions[#actions+1]={text="Citer un article",id="article"}
      actions[#actions+1]={text="Modifier le contexte",id="summary"}
      actions[#actions+1]={text="Changer le statut",id="status"}
    end
    if allowed("judgment") then
      actions[#actions+1]={text="Rediger un jugement",id="judgment"}
    end

    local a=menu(
      c.id.." - "..c.title,
      actions,
      "Statut: "..c.status.." / "..#c.facts.." faits / "..#c.evidence.." preuves / "..#c.judgments.." jugement(s)"
    )
    if not a then return end

    if a.id=="read" then
      local facts={}
      for i,f in ipairs(c.facts) do facts[#facts+1]=i..". "..f.text end
      local ev={}
      for i,e in ipairs(c.evidence) do
        ev[#ev+1]=i..". "..e.label..": "..e.description.." ("..(e.source or "")..")"
      end
      local js={}
      for i,j in ipairs(c.judgments) do
        js[#js+1]="Jugement "..i.." / "..j.date.." / "..j.judge..
          "\nDecision: "..j.verdict..
          "\nMotifs: "..j.reasoning..
          "\nSanctions: "..j.sanctions
      end
      textPage(c.id,{
        {label="Affaire",text=c.title},
        {label="Parties",text="Demandeur: "..c.complainant.."\nMis en cause: "..c.accused},
        {label="Contexte",text=c.summary},
        {label="Faits",text=table.concat(facts,"\n")},
        {label="Preuves",text=table.concat(ev,"\n")},
        {label="Articles cites",text=table.concat(c.citedArticles,", ")},
        {label="Jugements",text=table.concat(js,"\n\n")}
      })

    elseif a.id=="print" then
      local ok,r=printer.caseFile(c)
      message("IMPRESSION",ok and ("Dossier imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

    elseif a.id=="fact" then
      local text=multi("NOUVEAU FAIT","")
      local r,e=rpc("CASE_ADD_FACT",{id=c.id,text=text})
      message("FAIT",r and "Fait enregistre et horodate." or e,r and palette.ok or palette.bad)

    elseif a.id=="evidence" then
      local label=prompt("Nom de la preuve")
      local source=prompt("Source / origine")
      local description=multi("DESCRIPTION DE LA PREUVE","")
      local r,e=rpc("CASE_ADD_EVIDENCE",{
        id=c.id,label=label,source=source,description=description
      })
      message("PREUVE",r and "Preuve ajoutee au dossier." or e,r and palette.ok or palette.bad)

    elseif a.id=="article" then
      local mode=menu("CITER UN ARTICLE",{
        {text="Parcourir les categories",id="browse"},
        {text="Rechercher par numero / titre / mot",id="search"},
        {text="Saisir une reference manuellement",id="manual"}
      },"Le dossier reste ouvert pendant la consultation du Code.")
      local ref=nil
      if mode and mode.id=="manual" then
        ref=prompt("Reference article (ex: 145 ou UNS-ART-145)")
      elseif mode then
        local law=referenceBrowser({mode=mode.id,pick=true,readonly=true})
        if law then ref=law.ref end
      end
      if ref and ref~="" then
        local r,e=rpc("CASE_ADD_ARTICLE",{id=c.id,ref=ref})
        message("ARTICLE CITE",r and ("Reference ajoutee: "..ref) or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="summary" then
      local summary=multi("CONTEXTE / EXPOSE",c.summary)
      local r,e=rpc("CASE_UPDATE_SUMMARY",{id=c.id,summary=summary})
      message("DOSSIER",r and "Contexte mis a jour." or e,r and palette.ok or palette.bad)

    elseif a.id=="status" then
      local s=menu("STATUT DOSSIER",{
        {text="Ouvert",v="open"},
        {text="Enquete",v="investigation"},
        {text="Audience",v="hearing"},
        {text="Juge",v="judged"},
        {text="Appel",v="appeal"},
        {text="Clos",v="closed"},
        {text="Archive",v="archived"}
      })
      if s then
        local r,e=rpc("CASE_SET_STATUS",{id=c.id,status=s.v})
        message("STATUT",r and ("Statut: "..r.status) or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="judgment" then
      local verdict=multi("DISPOSITIF / DECISION","")
      local reasoning=multi("MOTIVATION","")
      local sanctions=multi("PEINES / SANCTIONS / REPARATIONS","")
      local final=prompt("Jugement final ? (oui/non)","oui"):lower():sub(1,1)=="o"
      local r,e=rpc("CASE_ADD_JUDGMENT",{
        id=c.id,verdict=verdict,reasoning=reasoning,sanctions=sanctions,final=final
      })
      message("JUGEMENT",r and "Jugement enregistre dans l'historique." or e,r and palette.ok or palette.bad)
    end
  end
end

local function casesScreen(query)
  while true do
    local cases,err=rpc("CASE_LIST",{query=query or ""})
    if not cases then message("DOSSIERS",err,palette.bad);return end

    local items={}
    if allowed("caseWrite") then
      items[#items+1]={text="[+] Ouvrir un nouveau dossier",id="new"}
    end
    items[#items+1]={text="[?] Rechercher",id="search"}

    for _,c in ipairs(cases) do
      items[#items+1]={
        text=c.id.."  "..c.title.."  ["..c.status.."]",
        case=c
      }
    end

    local p=menu("DOSSIERS JUDICIAIRES",items,#cases.." dossier(s)")
    if not p then return end

    if p.id=="new" then
      local title=prompt("Titre de l'affaire")
      local complainant=prompt("Demandeur / plaignant")
      local accused=prompt("Mis en cause")
      local summary=multi("CONTEXTE INITIAL","")
      local r,e=rpc("CASE_CREATE",{
        title=title,complainant=complainant,accused=accused,summary=summary
      })
      message("DOSSIER",r and ("Dossier cree: "..r.id) or e,r and palette.ok or palette.bad)

    elseif p.id=="search" then
      query=prompt("Recherche",query or "")

    elseif p.case then
      caseDetails(p.case.id)
    end
  end
end

local function auditScreen()
  local rows,err=rpc("AUDIT_LIST",{limit=100})
  if not rows then message("JOURNAL",err,palette.bad);return end

  local items={}
  for _,a in ipairs(rows) do
    items[#items+1]={
      text=(a.at or "").." | "..(a.action or "").." | "..(a.objectId or "").." | "..(a.actor or ""),
      a=a
    }
  end

  while true do
    local p=menu("JOURNAL D'AUDIT",items,"Historique serveur - append-only au niveau applicatif")
    if not p then return end
    textPage("AUDIT",{{
      label=p.a.action,
      text=(p.a.details or "")..
        "\nObjet: "..(p.a.objectId or "")..
        "\nAuteur: "..(p.a.actor or "").." / "..(p.a.role or "")..
        "\nDate: "..(p.a.at or "")..
        "\nRevision: "..tostring(p.a.revision or "")
    }})
  end
end

local function networkScreen()
  local info,e=rpc("SERVER_INFO",{})
  local available,pname=printer.available()
  clear()
  bar("ETAT DU TERMINAL")
  at(2,4,"Terminal : #"..os.getComputerID().." / "..(cfg.label or ""),palette.text)
  at(2,5,"Role     : "..(cfg.role or "?"),palette.accent)
  at(2,6,"Serveur  : #"..tostring(cfg.serverId),info and palette.ok or palette.bad)
  at(2,7,"Version  : "..common.VERSION,palette.muted)
  at(2,8,"Imprimante: "..(available and ("OK ("..pname..")") or "absente"),available and palette.ok or palette.warn)
  if info then
    at(2,10,"Revision serveur: "..tostring(info.meta.revision),palette.muted)
    at(2,11,"Etat du code: "..tostring(info.meta.codeStatus),palette.muted)
  else
    at(2,10,"Erreur: "..tostring(e),palette.bad)
  end
  wait()
end

function C.setupClient(expectedRole)
  common.ensureLayout()
  if common.openModems()==0 then
    error("Aucun modem detecte. Connectez un modem puis recommencez.",0)
  end

  clear()
  bar("APPAIRAGE","Le serveur doit afficher un code a usage unique cree avec [P].")
  local code=prompt("Code a 6 chiffres")
  local label=prompt("Nom de ce terminal",expectedRole.."-"..os.getComputerID())
  local rid=tostring(common.nowMs()).."-"..common.randomToken(5)

  rednet.broadcast({
    kind="pair_request",requestId=rid,code=code,
    label=label,requestedRole=expectedRole
  },common.PROTOCOL)

  at(2,5,"Recherche du serveur...",palette.muted)
  local timer=os.startTimer(8)

  while true do
    local ev,a,b,c=os.pullEvent()
    if ev=="rednet_message" and c==common.PROTOCOL and
       type(b)=="table" and b.kind=="pair_response" and b.requestId==rid then

      if not b.ok then error("Appairage refuse: "..tostring(b.error),0) end
      local d=b.data
      cfg={
        role=d.role,label=d.label,serverId=d.serverId,
        clientId=d.clientId,token=d.token,
        installedAt=common.now(),version=common.VERSION
      }
      common.saveConfig(cfg)
      print("Appairage reussi avec serveur #"..d.serverId.." / role "..d.role)
      if expectedRole and d.role~=expectedRole then
        print("Note: le serveur a attribue le role "..d.role.." au lieu de "..expectedRole..".")
      end
      sleep(1)
      return

    elseif ev=="timer" and a==timer then
      error("Aucun serveur n'a accepte le code dans les 8 secondes.",0)
    end
  end
end

function C.run()
  cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then
    error("Ce terminal n'est pas configure comme client.",0)
  end

  common.openModems()

  while true do
    local dash,err=rpc("DASHBOARD",{})
    local subtitle=dash and
      ("Role "..cfg.role.." | "..dash.laws.." articles | "..dash.cases.." dossiers | rev "..dash.revision)
      or ("HORS LIGNE - "..tostring(err))

    local items={
      {text="CODE INTERNATIONAL / ARTICLES",id="laws"},
      {text="DOSSIERS JUDICIAIRES",id="cases"},
      {text="RECHERCHE GLOBALE",id="search"}
    }
    if allowed("audit") then
      items[#items+1]={text="JOURNAL D'AUDIT",id="audit"}
    end
    items[#items+1]={text="RESEAU / IMPRIMANTE / DIAGNOSTIC",id="network"}
    items[#items+1]={text="QUITTER",id="quit"}

    local p=menu("BUREAU JURIDIQUE",items,subtitle)
    if not p or p.id=="quit" then clear();return end

    if p.id=="laws" then
      lawsScreen("")
    elseif p.id=="cases" then
      casesScreen("")
    elseif p.id=="search" then
      local q=prompt("Recherche (article, titre, partie)")
      local kind=menu("RECHERCHE",{
        {text="Dans les articles",id="law"},
        {text="Dans les dossiers",id="case"}
      })
      if kind and kind.id=="law" then lawsScreen(q)
      elseif kind then casesScreen(q) end
    elseif p.id=="audit" then
      auditScreen()
    elseif p.id=="network" then
      networkScreen()
    end
  end
end

function C.doctor()
  cfg=common.loadConfig()
  common.openModems()
  clear()
  bar("DIAGNOSTIC")
  local y=4
  at(2,y,"Configuration: "..(cfg and "OK" or "ABSENTE"),cfg and palette.ok or palette.bad)
  y=y+1
  local modems=common.openModems()
  at(2,y,"Modem(s): "..modems,modems>0 and palette.ok or palette.bad)
  y=y+1
  local pa,pn=printer.available()
  at(2,y,"Imprimante: "..(pa and pn or "absente"),pa and palette.ok or palette.warn)
  y=y+1
  if cfg and cfg.role~="server" then
    local d,e=rpc("PING",{},3)
    at(2,y,"Serveur: "..(d and "OK" or ("ERREUR - "..tostring(e))),d and palette.ok or palette.bad)
  end
  wait()
end

return C
