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
local lawBasketBrowser
local menu

local function splitDraft(text)
  text=tostring(text or ""):gsub("\r\n","\n"):gsub("\r","\n")
  local lines={}
  local pos=1
  while true do
    local s,e=text:find("\n",pos,true)
    if not s then
      lines[#lines+1]=text:sub(pos)
      break
    end
    lines[#lines+1]=text:sub(pos,s-1)
    pos=e+1
  end
  if #lines==0 then lines[1]="" end
  return lines
end

local function joinDraft(lines)
  return table.concat(lines,"\n")
end

local function multi(label,initial)
  common.ensureLayout()
  local draftsDir=common.ROOT.."/drafts"
  if not fs.exists(draftsDir) then fs.makeDir(draftsDir) end

  local path=draftsDir.."/draft-"..os.getComputerID().."-"..common.randomToken(6)..".txt"

  local function browseOldDrafts()
    local names=fs.list(draftsDir)
    local items={}
    local currentName=fs.getName(path)
    table.sort(names)
    for _,name in ipairs(names) do
      if name~=currentName and not fs.isDir(draftsDir.."/"..name) then
        local raw=common.readAll(draftsDir.."/"..name) or ""
        local preview=raw:gsub("\n"," "):gsub("%s+"," ")
        items[#items+1]={text=name.." | "..preview:sub(1,30),name=name,raw=raw}
      end
    end
    if #items==0 then
      message("BROUILLONS","Aucun autre brouillon recuperable sur ce PC.",palette.warn)
      return nil
    end

    while true do
      local p=menu("BROUILLONS RECUPERABLES",items,#items.." sauvegarde(s) locale(s)")
      if not p then return nil end
      local a=menu(p.name,{
        {text="Inserer ce brouillon a la position du curseur",id="insert"},
        {text="Supprimer definitivement ce brouillon",id="delete"}
      },"Apercu: "..(p.raw:gsub("\n"," "):sub(1,40)))
      if a and a.id=="insert" then
        return p.raw
      elseif a and a.id=="delete" then
        fs.delete(draftsDir.."/"..p.name)
        return nil
      end
    end
  end

  local lines=splitDraft(initial or "")
  local cy=1
  local cx=#lines[1]+1
  local top=1
  local left=1
  local dirty=true
  local citationBasket={}

  local function save()
    common.writeAll(path,joinDraft(lines))
    dirty=false
  end

  local function clampCursor()
    if cy<1 then cy=1 end
    if cy>#lines then cy=#lines end
    if cx<1 then cx=1 end
    local max=#lines[cy]+1
    if cx>max then cx=max end
  end

  local function dimensions()
    local w,h=term.getSize()
    local bodyTop=4
    local bodyBottom=math.max(bodyTop,h-2)
    local visible=math.max(1,bodyBottom-bodyTop+1)
    local textX=6
    local bodyWidth=math.max(8,w-textX)
    return w,h,bodyTop,bodyBottom,visible,textX,bodyWidth
  end

  local function ensureVisible()
    clampCursor()
    local _,_,_,_,visible,_,bodyWidth=dimensions()
    if cy<top then top=cy end
    if cy>=top+visible then top=cy-visible+1 end
    if top<1 then top=1 end

    if cx<left then left=cx end
    if cx>left+bodyWidth-1 then left=cx-bodyWidth+1 end
    if left<1 then left=1 end
  end

  local function render()
    ensureVisible()
    local w,h,bodyTop,bodyBottom,visible,textX,bodyWidth=dimensions()
    clear()
    bar(label,"Edition directe + consultation du Code sans perdre le brouillon")

    for row=bodyTop,bodyBottom do
      local lineNo=top+(row-bodyTop)
      term.setBackgroundColor(palette.bg)
      if lineNo<=#lines then
        at(1,row,string.format("%4d ",lineNo),lineNo==cy and palette.accent or palette.muted)
        local raw=lines[lineNo] or ""
        local shown=raw:sub(left,left+bodyWidth-1)
        at(textX,row,common.fit(shown,bodyWidth),palette.text)
      else
        at(1,row,common.fit("~",w),palette.muted)
      end
    end

    local state=dirty and "AUTO*" or "AUTO"
    footer("F2 Cat F3 Cherch F4 Cite F6 Panier F7 Draft F5 Fin "..state)

    local screenX=textX+(cx-left)
    local screenY=bodyTop+(cy-top)
    if screenX<textX then screenX=textX end
    if screenX>w then screenX=w end
    if screenY<bodyTop then screenY=bodyTop end
    if screenY>bodyBottom then screenY=bodyBottom end
    term.setCursorPos(screenX,screenY)
    term.setCursorBlink(true)
  end

  local function markChanged()
    dirty=true
    save()
  end

  local function insertChunk(chunk)
    chunk=tostring(chunk or ""):gsub("\r\n","\n"):gsub("\r","\n")
    local parts=splitDraft(chunk)
    local line=lines[cy]
    local before=line:sub(1,cx-1)
    local after=line:sub(cx)

    if #parts==1 then
      lines[cy]=before..parts[1]..after
      cx=cx+#parts[1]
    else
      lines[cy]=before..parts[1]
      local insertAt=cy+1
      for i=2,#parts-1 do
        table.insert(lines,insertAt,parts[i])
        insertAt=insertAt+1
      end
      table.insert(lines,insertAt,parts[#parts]..after)
      cy=insertAt
      cx=#parts[#parts]+1
    end
    markChanged()
  end

  save()

  while true do
    render()
    local ev,a,b,c=os.pullEvent()

    if ev=="char" then
      insertChunk(a)

    elseif ev=="paste" then
      insertChunk(a)

    elseif ev=="key" then
      if a==keys.left then
        if cx>1 then
          cx=cx-1
        elseif cy>1 then
          cy=cy-1
          cx=#lines[cy]+1
        end

      elseif a==keys.right then
        if cx<=#lines[cy] then
          cx=cx+1
        elseif cy<#lines then
          cy=cy+1
          cx=1
        end

      elseif a==keys.up then
        if cy>1 then
          cy=cy-1
          cx=math.min(cx,#lines[cy]+1)
        end

      elseif a==keys.down then
        if cy<#lines then
          cy=cy+1
          cx=math.min(cx,#lines[cy]+1)
        end

      elseif a==keys.home then
        cx=1

      elseif a==keys["end"] then
        cx=#lines[cy]+1

      elseif a==keys.pageUp then
        local _,_,_,_,visible=dimensions()
        cy=math.max(1,cy-visible)
        cx=math.min(cx,#lines[cy]+1)

      elseif a==keys.pageDown then
        local _,_,_,_,visible=dimensions()
        cy=math.min(#lines,cy+visible)
        cx=math.min(cx,#lines[cy]+1)

      elseif a==keys.backspace then
        if cx>1 then
          local line=lines[cy]
          lines[cy]=line:sub(1,cx-2)..line:sub(cx)
          cx=cx-1
          markChanged()
        elseif cy>1 then
          local previous=lines[cy-1]
          local current=table.remove(lines,cy)
          cy=cy-1
          cx=#previous+1
          lines[cy]=previous..current
          markChanged()
        end

      elseif a==keys.delete then
        local line=lines[cy]
        if cx<=#line then
          lines[cy]=line:sub(1,cx-1)..line:sub(cx+1)
          markChanged()
        elseif cy<#lines then
          lines[cy]=line..table.remove(lines,cy+1)
          markChanged()
        end

      elseif a==keys.enter then
        local line=lines[cy]
        local before=line:sub(1,cx-1)
        local after=line:sub(cx)
        lines[cy]=before
        table.insert(lines,cy+1,after)
        cy=cy+1
        cx=1
        markChanged()

      elseif a==keys.tab then
        insertChunk("  ")

      elseif a==keys.f2 then
        save()
        term.setCursorBlink(false)
        if referenceBrowser then referenceBrowser({mode="browse",readonly=true}) end

      elseif a==keys.f3 then
        save()
        term.setCursorBlink(false)
        if referenceBrowser then referenceBrowser({mode="search",readonly=true}) end

      elseif a==keys.f4 then
        save()
        term.setCursorBlink(false)
        local law=referenceBrowser and referenceBrowser({mode="browse",pick=true,readonly=true}) or nil
        if law then insertChunk("["..law.ref.."] "..law.title) end

      elseif a==keys.f6 then
        save()
        term.setCursorBlink(false)
        if lawBasketBrowser then
          local picked=lawBasketBrowser(citationBasket)
          if picked then
            citationBasket=picked
            if #citationBasket>0 then
              local action=menu("PANIER JURIDIQUE",{
                {text="Inserer les "..#citationBasket.." reference(s) au curseur",id="insert"},
                {text="Garder le panier et reprendre l'ecriture",id="keep"}
              },"La selection reste disponible pendant cette redaction.")
              if action and action.id=="insert" then
                local chunks={}
                for _,law in ipairs(citationBasket) do
                  chunks[#chunks+1]="["..law.ref.."] "..(law.title or "")
                end
                insertChunk(table.concat(chunks,"\n"))
              end
            end
          end
        end

      elseif a==keys.f7 then
        save()
        term.setCursorBlink(false)
        local recovered=browseOldDrafts()
        if recovered and recovered~="" then insertChunk(recovered) end

      elseif a==keys.f5 then
        save()
        term.setCursorBlink(false)
        local text=joinDraft(lines)
        if fs.exists(path) then fs.delete(path) end
        return text

      elseif a==keys.escape then
        save()
        term.setCursorBlink(false)
        local action=menu("QUITTER L'EDITEUR",{
          {text="Continuer la redaction",id="resume"},
          {text="Terminer et utiliser ce texte",id="finish"}
        },"Le brouillon est autosauvegarde.")
        if action and action.id=="finish" then
          local text=joinDraft(lines)
          if fs.exists(path) then fs.delete(path) end
          return text
        end
      end

    elseif ev=="mouse_click" then
      local _,_,bodyTop,bodyBottom,_,textX=dimensions()
      local x,y=b,c
      if y>=bodyTop and y<=bodyBottom then
        local lineNo=top+(y-bodyTop)
        if lineNo>=1 and lineNo<=#lines then
          cy=lineNo
          if x<textX then
            cx=1
          else
            cx=math.min(#lines[cy]+1,left+(x-textX))
          end
        end
      end

    elseif ev=="mouse_scroll" then
      if a<0 then cy=math.max(1,cy-3) else cy=math.min(#lines,cy+3) end
      cx=math.min(cx,#lines[cy]+1)

    elseif ev=="term_resize" then
      -- Le prochain render recalculera la zone visible.
    end
  end
end

menu=function(title,items,subtitle)
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
    if opts.mode=="search" then
      local q=prompt("Recherche article / mot / numero")
      if q=="" then return nil end
      local found,e=rpc("LAW_LIST",{query=q,status=opts.status or ""})
      if not found then message("RECHERCHE",e,palette.bad);return nil end
      local chosen=chooseLawFromList("RESULTATS: "..q,found,opts)
      if chosen or opts.pick then return chosen end
      opts.mode="browse"
    else
      local books,err=rpc("LAW_BOOKS",{})
      if not books then message("CODE",err,palette.bad);return nil end

      local items={
        {text="[?] Rechercher dans le Code",id="search"},
        {text="[*] Parcourir tous les articles",id="all"}
      }
      local total=0
      for _,book in ipairs(books) do
        total=total+(book.count or 0)
        items[#items+1]={
          text=book.name.."  ("..tostring(book.count or 0)..")",
          book=book
        }
      end

      local p=menu("BIBLIOTHEQUE DU CODE",items,total.." articles / "..#books.." categories")
      if not p then return nil end

      if p.id=="search" then
        local q=prompt("Recherche article / mot / numero")
        if q~="" then
          local found,e=rpc("LAW_LIST",{query=q,status=opts.status or ""})
          if not found then
            message("RECHERCHE",e,palette.bad)
          else
            local chosen=chooseLawFromList("RESULTATS: "..q,found,opts)
            if chosen then return chosen end
          end
        end
      elseif p.id=="all" then
        local all,e=rpc("LAW_LIST",{query="",status=opts.status or ""})
        if not all then
          message("CODE",e,palette.bad)
        else
          local chosen=chooseLawFromList("TOUS LES ARTICLES",all,opts)
          if chosen then return chosen end
        end
      elseif p.book then
        local laws,e=rpc("LAW_LIST",{book=p.book.name,status=opts.status or ""})
        if not laws then
          message("CODE",e,palette.bad)
        else
          local range=""
          if p.book.first and p.book.last then
            range=" / UNS-ART-"..string.format("%03d",p.book.first).." a "..string.format("%03d",p.book.last)
          end
          local chosen=chooseLawFromList(p.book.name,laws,opts)
          if chosen then return chosen end
        end
      end
    end
  end
end


lawBasketBrowser=function(initial)
  local selected={}
  local order={}

  local function addLaw(law)
    if not law or not law.ref then return end
    if not selected[law.ref] then
      selected[law.ref]={ref=law.ref,title=law.title or law.ref,status=law.status,book=law.book}
      order[#order+1]=law.ref
    else
      selected[law.ref].title=law.title or selected[law.ref].title
      selected[law.ref].status=law.status or selected[law.ref].status
      selected[law.ref].book=law.book or selected[law.ref].book
    end
  end

  for _,law in ipairs(initial or {}) do
    if type(law)=="table" then
      addLaw(law)
    elseif type(law)=="string" then
      local full=rpc("LAW_GET",{ref=law})
      if full then addLaw(full) end
    end
  end

  local function selectedList()
    local out={}
    for _,ref in ipairs(order) do
      if selected[ref] then out[#out+1]=selected[ref] end
    end
    return out
  end

  local function toggleList(title,laws)
    while true do
      local items={}
      for _,law in ipairs(laws or {}) do
        items[#items+1]={
          text=(selected[law.ref] and "[X] " or "[ ] ")..law.ref.."  "..law.title,
          law=law
        }
      end
      local p=menu(title,items,"Entree: ajouter/retirer ou lire. Retour: panier.")
      if not p then return end
      local law=p.law
      local a=menu(law.ref.." - "..law.title,{
        {text=selected[law.ref] and "Retirer de la selection" or "Ajouter a la selection",id="toggle"},
        {text="Lire l'article",id="read"}
      },(selected[law.ref] and "DEJA SELECTIONNE" or "NON SELECTIONNE"))
      if a and a.id=="toggle" then
        if selected[law.ref] then
          selected[law.ref]=nil
        else
          addLaw(law)
        end
      elseif a and a.id=="read" then
        lawQuickView(law)
      end
    end
  end

  while true do
    local current=selectedList()
    local items={
      {text="[+] Ajouter depuis les Livres / categories",id="books"},
      {text="[?] Ajouter depuis une recherche",id="search"},
      {text="[V] Voir / retirer la selection ("..#current..")",id="selected"},
      {text="[OK] Valider la selection ("..#current..")",id="done"},
      {text="[X] Vider le panier",id="clear"}
    }

    local p=menu("PANIER JURIDIQUE",items,#current.." article(s) selectionne(s)")
    if not p then return current end

    if p.id=="books" then
      local books,err=rpc("LAW_BOOKS",{})
      if not books then
        message("CODE",err,palette.bad)
      else
        local bookItems={}
        for _,b in ipairs(books) do
          bookItems[#bookItems+1]={text=b.name.." ("..tostring(b.count or 0)..")",book=b}
        end
        local bp=menu("CHOISIR UN LIVRE",bookItems,"Ouvrez un Livre puis cochez plusieurs articles.")
        if bp and bp.book then
          local laws,e=rpc("LAW_LIST",{book=bp.book.name})
          if laws then toggleList(bp.book.name,laws) else message("CODE",e,palette.bad) end
        end
      end

    elseif p.id=="search" then
      local q=prompt("Recherche article / mot / numero")
      if q~="" then
        local laws,e=rpc("LAW_LIST",{query=q})
        if laws then toggleList("RESULTATS: "..q,laws) else message("RECHERCHE",e,palette.bad) end
      end

    elseif p.id=="selected" then
      local currentLaws=selectedList()
      if #currentLaws==0 then
        message("PANIER","Aucun article selectionne.",palette.warn)
      else
        toggleList("SELECTION ACTUELLE",currentLaws)
      end

    elseif p.id=="clear" then
      selected={}
      order={}

    elseif p.id=="done" then
      return selectedList()
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

local function lawHistoryScreen(law)
  local versions={}
  versions[#versions+1]={
    text="Version actuelle v"..tostring(law.version or 1).." ["..tostring(law.status or "?").."]",
    current=true,
    version=law.version,
    title=law.title,
    body=law.body,
    book=law.book,
    section=law.section,
    status=law.status,
    archivedAt=law.updatedAt or law.createdAt
  }

  for i=#(law.history or {}),1,-1 do
    local h=law.history[i]
    versions[#versions+1]={
      text="Version archivee v"..tostring(h.version or "?").." ["..tostring(h.status or "?").."] "..tostring(h.archivedAt or ""),
      history=h
    }
  end

  while true do
    local p=menu("HISTORIQUE "..law.ref,versions,#versions.." version(s) conservee(s)")
    if not p then return end
    local v=p.current and p or p.history
    textPage(law.ref.." / v"..tostring(v.version or "?"),{
      {label=v.title or law.title,text=v.body or "(texte non archive dans cette ancienne entree)"},
      {label="Classement",text=(v.book or law.book or "").." / "..(v.section or law.section or "")},
      {label="Statut",text=tostring(v.status or "?")},
      {label="Archive / mise a jour",text=tostring(v.archivedAt or law.updatedAt or "")},
      {label="Auteur archive",text=tostring(v.archivedBy or "-")}
    })
  end
end

local function sameBookScreen(law)
  if not law.book or law.book=="" then
    message("LIVRE","Cet article n'a pas de categorie.",palette.warn)
    return
  end
  local laws,err=rpc("LAW_LIST",{book=law.book})
  if not laws then message("LIVRE",err,palette.bad);return end
  while true do
    local picked=chooseLawFromList(law.book,laws,{manage=true})
    if not picked then return end
    if picked.ref~=law.ref then
      return picked.ref
    else
      lawQuickView(picked)
    end
  end
end

local function viewLaw(ref)
  while true do
    local law,err=rpc("LAW_GET",{ref=ref})
    if not law then message("ARTICLE",err,palette.bad);return end

    local actions={
      {text="Lire le texte",id="read"},
      {text="Historique des versions",id="history"},
      {text="Voir les articles du meme Livre",id="book"},
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

    elseif a.id=="history" then
      lawHistoryScreen(law)

    elseif a.id=="book" then
      local nextRef=sameBookScreen(law)
      if nextRef then ref=nextRef end

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

local function lawsScreen(query,status)
  query=query or ""
  status=status or ""

  while true do
    local items={}
    if allowed("lawWrite") then
      items[#items+1]={text="[+] Creer un nouvel article",id="new"}
    end
    items[#items+1]={text="[L] Parcourir par LIVRE / categorie",id="books"}
    items[#items+1]={text="[?] Rechercher par numero, titre ou mot",id="search"}
    items[#items+1]={text="[S] Filtrer par statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    items[#items+1]={text="[*] Afficher tous les articles",id="all"}
    if query~="" or status~="" then
      items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"}
    end

    local subtitle="Categories + recherche"
    if status~="" then subtitle=subtitle.." / statut "..status end
    local pick=menu("CODE INTERNATIONAL",items,subtitle)
    if not pick then return end

    if pick.id=="new" then
      local title=prompt("Titre")
      local books=rpc("LAW_BOOKS",{}) or {}
      local bookItems={}
      for _,b in ipairs(books) do bookItems[#bookItems+1]={text=b.name.." ("..tostring(b.count or 0)..")",book=b.name} end
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
        local law=referenceBrowser({mode="browse",manage=true,status=status})
        if not law then break end
        viewLaw(law.ref)
      end

    elseif pick.id=="search" then
      while true do
        local q=prompt("Recherche",query)
        if q=="" then break end
        query=q
        local laws,err=rpc("LAW_LIST",{query=q,status=status})
        if not laws then
          message("CODE",err,palette.bad)
          break
        end
        local law=chooseLawFromList("RESULTATS: "..q,laws,{manage=true})
        if law then viewLaw(law.ref) else break end
      end

    elseif pick.id=="status" then
      local s=menu("FILTRER LES ARTICLES",{
        {text="Tous les statuts",v=""},
        {text="Actifs / ratifies",v="active"},
        {text="Brouillons",v="draft"},
        {text="Suspendus",v="suspended"},
        {text="Abroges",v="repealed"}
      })
      if s then status=s.v end

    elseif pick.id=="all" then
      local laws,err=rpc("LAW_LIST",{query="",status=status})
      if not laws then message("CODE",err,palette.bad)
      else
        while true do
          local law=chooseLawFromList("TOUS LES ARTICLES",laws,{manage=true})
          if not law then break end
          viewLaw(law.ref)
        end
      end

    elseif pick.id=="reset" then
      query=""
      status=""
    end
  end
end

local function caseTimelineScreen(c)
  local sections={}
  if not c.timeline or #c.timeline==0 then
    sections[#sections+1]={label="Chronologie",text="Aucun evenement historique enregistre pour ce dossier ancien."}
  else
    for i,event in ipairs(c.timeline) do
      sections[#sections+1]={
        label=string.format("%02d. %s",i,event.title or event.kind or "Evenement"),
        text=(event.at or "").." / "..(event.by or "?").." ["..(event.role or "?").."]"..
          ((event.details and event.details~="") and ("\n"..event.details) or "")
      }
    end
  end
  textPage("CHRONOLOGIE "..c.id,sections)
end

local function judgmentDetails(c,j)
  local refs={}
  if j.articleSnapshot and #j.articleSnapshot>0 then
    for _,a in ipairs(j.articleSnapshot) do
      refs[#refs+1]=(a.ref or "?")..
        (a.version and (" / v"..tostring(a.version)) or "")..
        ((a.title and a.title~="") and (" / "..a.title) or "")
    end
  else
    for _,ref in ipairs(j.citedArticles or {}) do refs[#refs+1]=ref end
  end
  textPage(c.id.." / JUGEMENT "..tostring(j.id or "?"),{
    {label="Juge / date",text=(j.judge or "?").." / "..(j.date or "")},
    {label="Nature",text=j.final and "Decision finale" or "Decision intermediaire"},
    {label="Decision",text=j.verdict or ""},
    {label="Motivation",text=j.reasoning or ""},
    {label="Sanctions / reparations",text=j.sanctions or ""},
    {label="Articles figes au jour du jugement",text=table.concat(refs,"\n")}
  })
end

local function judgmentsScreen(c)
  if not c.judgments or #c.judgments==0 then
    message("JUGEMENTS","Aucun jugement dans ce dossier.",palette.warn)
    return
  end

  while true do
    local items={}
    for i,j in ipairs(c.judgments) do
      items[#items+1]={
        text="J"..i.."  "..(j.date or "").."  "..(j.final and "[FINAL] " or "")..(j.verdict or ""):gsub("\n"," "),
        judgment=j
      }
    end
    local p=menu("JUGEMENTS "..c.id,items,#items.." decision(s) conservee(s)")
    if not p then return end
    local a=menu("JUGEMENT "..tostring(p.judgment.id or "?"),{
      {text="Lire la decision complete",id="read"},
      {text="Imprimer uniquement ce jugement",id="print"}
    },"Les versions des articles citees sont figees dans le jugement.")
    if a and a.id=="read" then
      judgmentDetails(c,p.judgment)
    elseif a and a.id=="print" then
      local ok,r=printer.judgment(c,p.judgment)
      message("IMPRESSION",ok and ("Jugement imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)
    end
  end
end

local function manageCaseArticles(c)
  local initial={}
  for _,ref in ipairs(c.citedArticles or {}) do initial[#initial+1]=ref end
  local picked=lawBasketBrowser(initial)
  if not picked then return end

  local old={}
  for _,ref in ipairs(initial) do old[ref]=true end
  local now={}
  local add={}
  for _,law in ipairs(picked) do
    now[law.ref]=true
    if not old[law.ref] then add[#add+1]=law.ref end
  end
  local remove={}
  for _,ref in ipairs(initial) do
    if not now[ref] then remove[#remove+1]=ref end
  end

  local errors={}
  if #add>0 then
    local _,e=rpc("CASE_ADD_ARTICLES",{id=c.id,refs=add})
    if e then errors[#errors+1]=e end
  end
  for _,ref in ipairs(remove) do
    local _,e=rpc("CASE_REMOVE_ARTICLE",{id=c.id,ref=ref})
    if e then errors[#errors+1]=ref..": "..e end
  end

  if #errors>0 then
    message("ARTICLES","Certaines modifications ont echoue:\n"..table.concat(errors," / "),palette.bad)
  else
    message("ARTICLES",#add.." ajoute(s), "..#remove.." retire(s).",palette.ok)
  end
end

local function caseDetails(id)
  while true do
    local c,err=rpc("CASE_GET",{id=id})
    if not c then message("DOSSIER",err,palette.bad);return end
    c.facts=c.facts or {}
    c.evidence=c.evidence or {}
    c.citedArticles=c.citedArticles or {}
    c.judgments=c.judgments or {}
    c.timeline=c.timeline or {}

    local actions={
      {text="Lire le dossier complet",id="read"},
      {text="Voir la chronologie du dossier",id="timeline"},
      {text="Consulter les jugements ("..#c.judgments..")",id="judgments"},
      {text="Imprimer le dossier complet",id="print"},
      {text="Imprimer la chronologie",id="printtimeline"}
    }

    if allowed("caseWrite") then
      actions[#actions+1]={text="Ajouter un fait",id="fact"}
      actions[#actions+1]={text="Ajouter une preuve",id="evidence"}
      actions[#actions+1]={text="Gerer les articles cites / panier juridique",id="articles"}
      actions[#actions+1]={text="Modifier le contexte",id="summary"}
      actions[#actions+1]={text="Changer le statut",id="status"}
    end
    if allowed("judgment") then
      actions[#actions+1]={text="Rediger un nouveau jugement",id="judgment"}
    end

    local a=menu(
      c.id.." - "..c.title,
      actions,
      "Statut "..c.status.." | "..#c.facts.." faits | "..#c.evidence.." preuves | "..#c.citedArticles.." articles | "..#c.judgments.." jug."
    )
    if not a then return end

    if a.id=="read" then
      local facts={}
      for i,fact in ipairs(c.facts) do facts[#facts+1]=i..". "..fact.text.." ["..(fact.by or "?").."]" end
      local ev={}
      for i,e in ipairs(c.evidence) do
        ev[#ev+1]=i..". "..e.label..": "..e.description..
          ((e.source and e.source~="") and (" / source: "..e.source) or "")
      end
      local js={}
      for i,j in ipairs(c.judgments) do
        js[#js+1]="J"..i.." / "..(j.date or "").." / "..(j.judge or "?")..
          (j.final and " / FINAL" or "").."\nDecision: "..(j.verdict or "")
      end
      textPage(c.id,{
        {label="Affaire",text=c.title},
        {label="Statut",text=c.status},
        {label="Parties",text="Demandeur: "..(c.complainant or "-").."\nMis en cause: "..(c.accused or "-")},
        {label="Contexte",text=c.summary or ""},
        {label="Faits",text=table.concat(facts,"\n")},
        {label="Preuves",text=table.concat(ev,"\n")},
        {label="Articles cites",text=table.concat(c.citedArticles,"\n")},
        {label="Jugements",text=table.concat(js,"\n\n")},
        {label="Derniere mise a jour",text=c.updatedAt or c.createdAt or ""}
      })

    elseif a.id=="timeline" then
      caseTimelineScreen(c)

    elseif a.id=="judgments" then
      judgmentsScreen(c)

    elseif a.id=="print" then
      local ok,r=printer.caseFile(c)
      message("IMPRESSION",ok and ("Dossier imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

    elseif a.id=="printtimeline" then
      local ok,r=printer.timeline(c)
      message("IMPRESSION",ok and ("Chronologie imprimee: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

    elseif a.id=="fact" then
      local text=multi("NOUVEAU FAIT","")
      local r,e=rpc("CASE_ADD_FACT",{id=c.id,text=text})
      message("FAIT",r and "Fait enregistre, horodate et ajoute a la chronologie." or e,r and palette.ok or palette.bad)

    elseif a.id=="evidence" then
      local label=prompt("Nom de la preuve")
      local source=prompt("Source / origine")
      local description=multi("DESCRIPTION DE LA PREUVE","")
      local r,e=rpc("CASE_ADD_EVIDENCE",{
        id=c.id,label=label,source=source,description=description
      })
      message("PREUVE",r and "Preuve ajoutee au dossier et a la chronologie." or e,r and palette.ok or palette.bad)

    elseif a.id=="articles" then
      manageCaseArticles(c)

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
      },"Le changement sera inscrit dans la chronologie.")
      if s then
        local r,e=rpc("CASE_SET_STATUS",{id=c.id,status=s.v})
        message("STATUT",r and ("Statut: "..r.status) or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="judgment" then
      if #c.citedArticles==0 then
        local prepare=menu("ARTICLES DU JUGEMENT",{
          {text="Constituer d'abord un panier d'articles",id="yes"},
          {text="Continuer sans article cite",id="no"}
        },"Le jugement figera les versions des articles cites.")
        if prepare and prepare.id=="yes" then
          manageCaseArticles(c)
          c=rpc("CASE_GET",{id=id}) or c
        end
      end

      local verdict=multi("DISPOSITIF / DECISION","")
      local reasoning=multi("MOTIVATION","")
      local sanctions=multi("PEINES / SANCTIONS / REPARATIONS","")
      local final=prompt("Jugement final ? (oui/non)","oui"):lower():sub(1,1)=="o"
      local r,e=rpc("CASE_ADD_JUDGMENT",{
        id=c.id,verdict=verdict,reasoning=reasoning,sanctions=sanctions,final=final
      })
      if r then
        local latest=r.judgments and r.judgments[#r.judgments] or nil
        local nextAction=menu("JUGEMENT ENREGISTRE",{
          {text="Revenir au dossier",id="back"},
          {text="Lire le jugement",id="read"},
          {text="Imprimer le jugement maintenant",id="print"}
        },"Decision archivee avec les versions des articles citees.")
        if nextAction and nextAction.id=="read" and latest then
          judgmentDetails(r,latest)
        elseif nextAction and nextAction.id=="print" and latest then
          local ok,pages=printer.judgment(r,latest)
          message("IMPRESSION",ok and ("Jugement imprime: "..pages.." page(s).") or pages,ok and palette.ok or palette.bad)
        end
      else
        message("JUGEMENT",e,palette.bad)
      end
    end
  end
end

local function casesScreen(query,status)
  query=query or ""
  status=status or ""
  while true do
    local cases,err=rpc("CASE_LIST",{query=query,status=status})
    if not cases then message("DOSSIERS",err,palette.bad);return end

    local items={}
    if allowed("caseWrite") then
      items[#items+1]={text="[+] Ouvrir un nouveau dossier",id="new"}
    end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer par statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then
      items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"}
    end

    for _,c in ipairs(cases) do
      items[#items+1]={
        text=c.id.."  "..c.title.."  ["..c.status.."]",
        case=c
      }
    end

    local filterText=""
    if query~="" then filterText=filterText.." recherche='"..query.."'" end
    if status~="" then filterText=filterText.." statut="..status end
    local p=menu("DOSSIERS JUDICIAIRES",items,#cases.." dossier(s)"..filterText)
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
      query=prompt("Recherche",query)

    elseif p.id=="status" then
      local s=menu("FILTRER LES DOSSIERS",{
        {text="Tous les statuts",v=""},
        {text="Ouverts",v="open"},
        {text="En enquete",v="investigation"},
        {text="En audience",v="hearing"},
        {text="Juges",v="judged"},
        {text="En appel",v="appeal"},
        {text="Clos",v="closed"},
        {text="Archives",v="archived"}
      })
      if s then status=s.v end

    elseif p.id=="reset" then
      query=""
      status=""

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

local function helpScreen()
  textPage("AIDE / RACCOURCIS",{
    {label="Navigation du Code",text="Parcourez par Livre, utilisez la recherche plein texte ou filtrez par statut. Un article peut etre ouvert, imprime et son historique de versions consulte."},
    {label="Editeur juridique",text="F2: Livres / categories\nF3: Recherche d'article\nF4: Inserer une citation a la position du curseur\nF6: Panier juridique multi-selection\nF7: Recuperer un brouillon autosauvegarde\nF5: Terminer la redaction\nEchap: menu de sortie"},
    {label="Dossiers",text="Le panier juridique permet d'ajouter ou retirer plusieurs articles d'un dossier. Chaque fait, preuve, changement de statut et jugement alimente la chronologie."},
    {label="Jugements",text="Lors de l'enregistrement, le systeme fige la reference, le titre et la version des articles cites. Un jugement peut ensuite etre relu ou imprime seul."},
    {label="Impression",text="Une imprimante ComputerCraft connectee permet d'imprimer le dossier complet, sa chronologie, un article ou un jugement individuel sur plusieurs pages."},
    {label="Sauvegarde",text="Les textes en cours sont autosauvegardes localement. Le serveur reste la source de verite pour les lois, dossiers, jugements et le journal d'audit."}
  })
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
    local sv=tostring(info.meta.version or "?")
    at(2,12,"Version serveur: "..sv,sv==common.VERSION and palette.ok or palette.warn)
    if sv~=common.VERSION then
      at(2,13,"Mise a jour conseillee sur serveur/client.",palette.warn)
    end
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
      ("Role "..cfg.role.." | "..dash.laws.." art. ("..tostring(dash.activeLaws or 0).." actifs) | "..tostring(dash.openCases or dash.cases).." dossiers ouverts | rev "..dash.revision)
      or ("HORS LIGNE - "..tostring(err))

    local items={
      {text="CODE INTERNATIONAL / ARTICLES",id="laws"},
      {text="DOSSIERS JUDICIAIRES",id="cases"},
      {text="RECHERCHE GLOBALE",id="search"}
    }
    if allowed("audit") then
      items[#items+1]={text="JOURNAL D'AUDIT",id="audit"}
    end
    items[#items+1]={text="AIDE / RACCOURCIS",id="help"}
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
    elseif p.id=="help" then
      helpScreen()
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
