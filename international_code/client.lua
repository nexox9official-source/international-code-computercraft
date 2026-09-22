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

local function bookLabel(book)
  if not book then return "SANS CATEGORIE" end
  local name=book.name or tostring(book)
  local prefix,rest=name:match("^(LIVRE%s+[^%-]+)%s*%-%s*(.*)$")
  if not prefix then return name end
  local range=""
  if book.first and book.last then range=" ["..tostring(book.first).."-"..tostring(book.last).."]" end
  return prefix..range.." "..rest
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
          text=bookLabel(book).."  ("..tostring(book.count or 0)..")",
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
  local inOrder={}

  local function addLaw(law)
    if not law or not law.ref then return end
    if not selected[law.ref] then
      selected[law.ref]={ref=law.ref,title=law.title or law.ref,status=law.status,book=law.book}
      if not inOrder[law.ref] then
        order[#order+1]=law.ref
        inOrder[law.ref]=true
      end
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
      local items={
        {text="[+] Ajouter toute cette liste au panier",id="all"},
        {text="[-] Retirer toute cette liste du panier",id="none"}
      }
      for _,law in ipairs(laws or {}) do
        items[#items+1]={
          text=(selected[law.ref] and "[X] " or "[ ] ")..law.ref.." ["..(law.status or "?").."] "..law.title,
          law=law
        }
      end
      local p=menu(title,items,"Selection multiple. Retour: panier.")
      if not p then return end

      if p.id=="all" then
        local count=0
        for _,law in ipairs(laws or {}) do
          if not selected[law.ref] then addLaw(law);count=count+1 end
        end
        message("PANIER",tostring(count).." article(s) ajoute(s) a la selection.",palette.ok)

      elseif p.id=="none" then
        local count=0
        for _,law in ipairs(laws or {}) do
          if selected[law.ref] then selected[law.ref]=nil;count=count+1 end
        end
        message("PANIER",tostring(count).." article(s) retire(s) de la selection.",palette.warn)

      elseif p.law then
        local law=p.law
        local a=menu(law.ref.." - "..law.title,{
          {text=selected[law.ref] and "Retirer de la selection" or "Ajouter a la selection",id="toggle"},
          {text="Lire l'article",id="read"}
        },(selected[law.ref] and "DEJA SELECTIONNE" or "NON SELECTIONNE"))

        if a and a.id=="toggle" then
          if selected[law.ref] then
            selected[law.ref]=nil
          else
            local allow=true
            if law.status=="repealed" or law.status=="suspended" then
              local confirm=menu("ARTICLE NON APPLICABLE",{
                {text="Ajouter quand meme",id="yes"},
                {text="Annuler",id="no"}
              },law.ref.." est actuellement ["..law.status.."]. Les brouillons restent selectionnables sans avertissement.")
              allow=confirm and confirm.id=="yes"
            end
            if allow then addLaw(law) end
          end
        elseif a and a.id=="read" then
          lawQuickView(law)
        end
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
          bookItems[#bookItems+1]={text=bookLabel(b).." ("..tostring(b.count or 0)..")",book=b}
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
      inOrder={}

    elseif p.id=="done" then
      return selectedList()
    end
  end
end


local enforcementsScreen
local createEnforcement

local roleAllows={
  lawWrite={writer=true,admin=true},
  caseWrite={clerk=true,judge=true,admin=true},
  judgment={judge=true,admin=true},
  orderWrite={judge=true,admin=true},
  visibilityWrite={judge=true,admin=true},
  appealDecide={judge=true,admin=true},
  enforcementWrite={judge=true,admin=true},
  enforcementProgress={clerk=true,judge=true,admin=true},
  legislature={writer=true,admin=true},
  resolutionWrite={writer=true,admin=true},
  resolutionVote={delegate=true},
  sessionWrite={writer=true,admin=true},
  sessionAttend={delegate=true},
  diplomacy={writer=true,admin=true},
  treatySign={delegate=true},
  delegateVote={delegate=true},
  institutionAdmin={admin=true},
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
      {label="Auteur archive",text=tostring(v.archivedBy or "-")},
      {label="Motif de remplacement",text=tostring(v.supersededByReason or law.lastChangeReason or "-")}
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
      local reason=prompt("Motif bref de la modification")
      local title=prompt("Nouveau titre (Entree = conserver)",law.title)
      local body=multi("NOUVELLE VERSION",law.body)
      local updated,e=rpc("LAW_AMEND",{
        ref=law.ref,title=title,body=body,book=law.book,section=law.section,reason=reason
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
      for _,b in ipairs(books) do bookItems[#bookItems+1]={text=bookLabel(b).." ("..tostring(b.count or 0)..")",book=b.name} end
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
    {label="Articles figes au jour du jugement",text=table.concat(refs,"\n")},
    {label="Sceau officiel",text=j.seal or "Ancienne decision sans sceau v0.4"}
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

local function hearingsScreen(c)
  while true do
    local items={}
    if allowed("caseWrite") then items[#items+1]={text="[+] Programmer une audience",id="new"} end
    for _,h in ipairs(c.hearings or {}) do
      items[#items+1]={
        text=(h.id or "?").."  "..(h.scheduledFor or "-").."  "..(h.subject or "").."  ["..(h.status or "?").."]",
        hearing=h
      }
    end
    local p=menu("AUDIENCES "..c.id,items,#(c.hearings or {}).." audience(s)")
    if not p then return end

    if p.id=="new" then
      local subject=prompt("Objet de l'audience")
      local scheduledFor=prompt("Date / heure (texte libre)")
      local location=prompt("Salle / lieu")
      local notes=multi("NOTES D'AUDIENCE","")
      local r,e=rpc("CASE_ADD_HEARING",{
        id=c.id,subject=subject,scheduledFor=scheduledFor,location=location,notes=notes
      })
      message("AUDIENCE",r and "Audience enregistree." or e,r and palette.ok or palette.bad)
      if r then c=r end

    elseif p.hearing then
      local h=p.hearing
      local actions={
        {text="Lire l'avis d'audience",id="read"},
        {text="Imprimer l'avis",id="print"}
      }
      if h.recordSeal then
        actions[#actions+1]={text="Lire le proces-verbal",id="minutes"}
        actions[#actions+1]={text="Imprimer le proces-verbal",id="printminutes"}
      end
      if allowed("caseWrite") then
        actions[#actions+1]={text=h.recordSeal and "Mettre a jour le proces-verbal" or "Enregistrer le proces-verbal",id="record"}
        actions[#actions+1]={text="Changer le statut",id="status"}
      end
      local a=menu(h.id.." - "..h.subject,actions,(h.scheduledFor or "").." / "..(h.status or ""))
      if a and a.id=="read" then
        textPage(c.id.." / "..h.id,{
          {label="Objet",text=h.subject or ""},
          {label="Date / heure",text=h.scheduledFor or ""},
          {label="Lieu",text=h.location or ""},
          {label="Statut",text=h.status or ""},
          {label="Notes",text=h.notes or ""},
          {label="Cree par",text=(h.createdBy or "").." / "..(h.createdAt or "")},
          {label="Sceau officiel",text=h.seal or "-"}
        })
      elseif a and a.id=="print" then
        local ok,r=printer.hearingNotice(c,h)
        message("IMPRESSION",ok and ("Avis imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

      elseif a and a.id=="minutes" then
        textPage(c.id.." / PV "..h.id,{
          {label="Audience",text=h.subject or ""},
          {label="Date / lieu",text=(h.scheduledFor or "").." / "..(h.location or "")},
          {label="Participants",text=h.participants or ""},
          {label="Proces-verbal",text=h.minutes or ""},
          {label="Issue / suite",text=h.outcome or ""},
          {label="Enregistre par",text=(h.recordedBy or "").." / "..(h.recordedAt or "")},
          {label="Sceau du PV",text=h.recordSeal or "-"}
        })

      elseif a and a.id=="printminutes" then
        local ok,r=printer.hearingMinutes(c,h)
        message("IMPRESSION",ok and ("Proces-verbal imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

      elseif a and a.id=="record" then
        local participants=multi("PARTICIPANTS A L'AUDIENCE",h.participants or "")
        local minutes=multi("PROCES-VERBAL / COMPTE RENDU",h.minutes or "")
        local outcome=multi("ISSUE / SUITE DE L'AUDIENCE",h.outcome or "")
        local r,e=rpc("CASE_RECORD_HEARING",{
          id=c.id,hearingId=h.id,participants=participants,minutes=minutes,outcome=outcome
        })
        message("AUDIENCE",r and "Proces-verbal enregistre, scelle et archive." or e,r and palette.ok or palette.bad)
        if r then c=r end

      elseif a and a.id=="status" then
        local st=menu("STATUT AUDIENCE",{
          {text="Programmee",v="scheduled"},{text="Tenue",v="held"},
          {text="Reportee",v="postponed"},{text="Annulee",v="cancelled"}
        })
        if st then
          local r,e=rpc("CASE_SET_HEARING_STATUS",{id=c.id,hearingId=h.id,status=st.v})
          message("AUDIENCE",r and ("Statut: "..st.v) or e,r and palette.ok or palette.bad)
          if r then c=r end
        end
      end
    end
  end
end

local function ordersScreen(c)
  while true do
    local items={}
    if allowed("orderWrite") then items[#items+1]={text="[+] Emettre une ordonnance / un mandat",id="new"} end
    for _,o in ipairs(c.orders or {}) do
      items[#items+1]={
        text=(o.id or "?").."  "..(o.orderType or "order").."  "..(o.subject or "").."  ["..(o.status or "?").."]",
        order=o
      }
    end
    local p=menu("ORDONNANCES "..c.id,items,#(c.orders or {}).." acte(s)")
    if not p then return end

    if p.id=="new" then
      local typ=menu("TYPE D'ACTE",{
        {text="Ordonnance judiciaire",v="order"},
        {text="Mandat",v="warrant"},
        {text="Mesure provisoire",v="interim"},
        {text="Convocation",v="summons"},
        {text="Preservation de preuves",v="evidence_preservation"}
      })
      if typ then
        local subject=prompt("Objet")
        local expiresAt=prompt("Expiration / duree (optionnel)")
        local body=multi("CONTENU DE L'ORDONNANCE","")
        local r,e=rpc("CASE_ADD_ORDER",{
          id=c.id,orderType=typ.v,subject=subject,expiresAt=expiresAt,body=body
        })
        message("ORDONNANCE",r and "Acte judiciaire enregistre." or e,r and palette.ok or palette.bad)
        if r then c=r end
      end

    elseif p.order then
      local o=p.order
      local actions={
        {text="Lire l'acte",id="read"},
        {text="Imprimer l'acte",id="print"}
      }
      if allowed("orderWrite") then actions[#actions+1]={text="Changer le statut",id="status"} end
      local a=menu(o.id.." - "..o.subject,actions,(o.orderType or "").." / "..(o.status or ""))
      if a and a.id=="read" then
        textPage(c.id.." / "..o.id,{
          {label="Type",text=o.orderType or ""},
          {label="Objet",text=o.subject or ""},
          {label="Contenu",text=o.body or ""},
          {label="Statut",text=o.status or ""},
          {label="Expiration",text=o.expiresAt or ""},
          {label="Emis par",text=(o.createdBy or "").." / "..(o.createdAt or "")},
          {label="Sceau officiel",text=o.seal or "-"}
        })
      elseif a and a.id=="print" then
        local ok,r=printer.order(c,o)
        message("IMPRESSION",ok and ("Acte imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)
      elseif a and a.id=="status" then
        local st=menu("STATUT DE L'ACTE",{
          {text="Actif",v="active"},{text="Execute",v="executed"},
          {text="Revoque",v="revoked"},{text="Expire",v="expired"}
        })
        if st then
          local r,e=rpc("CASE_SET_ORDER_STATUS",{id=c.id,orderId=o.id,status=st.v})
          message("ORDONNANCE",r and ("Statut: "..st.v) or e,r and palette.ok or palette.bad)
          if r then c=r end
        end
      end
    end
  end
end

local function appealsScreen(c)
  while true do
    local items={}
    if allowed("caseWrite") then items[#items+1]={text="[+] Deposer un appel",id="new"} end
    for _,a in ipairs(c.appeals or {}) do
      items[#items+1]={
        text=(a.id or "?").."  "..(a.appellant or "").."  ["..(a.status or "?").."]"..
          (a.result and (" -> "..a.result) or ""),
        appeal=a
      }
    end

    local p=menu("APPELS "..c.id,items,#(c.appeals or {}).." appel(s)")
    if not p then return end

    if p.id=="new" then
      local appellant=prompt("Appelant / partie")
      local grounds=multi("MOTIFS D'APPEL","")
      local request=multi("DEMANDE A LA COUR D'APPEL","")
      local r,e=rpc("CASE_FILE_APPEAL",{id=c.id,appellant=appellant,grounds=grounds,request=request})
      message("APPEL",r and "Appel depose et dossier place en appel." or e,r and palette.ok or palette.bad)
      if r then c=r end

    elseif p.appeal then
      local a=p.appeal
      local actions={
        {text="Lire l'appel",id="read"},
        {text="Imprimer l'acte d'appel",id="print"}
      }
      if allowed("appealDecide") and a.status=="pending" then
        actions[#actions+1]={text="Rendre la decision d'appel",id="decide"}
      end

      local action=menu(a.id.." - "..(a.appellant or ""),actions,a.status..(a.result and (" / "..a.result) or ""))
      if action and action.id=="read" then
        textPage(c.id.." / "..a.id,{
          {label="Appelant",text=a.appellant or ""},
          {label="Motifs",text=a.grounds or ""},
          {label="Demande",text=a.request or ""},
          {label="Depot",text=(a.filedAt or "").." / "..(a.filedBy or "")},
          {label="Sceau du depot",text=a.seal or "-"},
          {label="Statut / resultat",text=(a.status or "")..(a.result and (" / "..a.result) or "")},
          {label="Motivation de la decision",text=a.reasoning or ""},
          {label="Decision rendue par",text=(a.decidedBy or "").." / "..(a.decidedAt or "")},
          {label="Sceau de decision",text=a.decisionSeal or "-"}
        })

      elseif action and action.id=="print" then
        local ok,r=printer.appeal(c,a)
        message("IMPRESSION",ok and ("Acte d'appel imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

      elseif action and action.id=="decide" then
        local result=menu("DECISION D'APPEL",{
          {text="Confirmer la decision",v="upheld"},
          {text="Modifier la decision",v="modified"},
          {text="Annuler la decision",v="overturned"},
          {text="Renvoyer l'affaire pour nouvelle audience",v="remanded"},
          {text="Rejeter l'appel",v="rejected"}
        })
        if result then
          local reasoning=multi("MOTIVATION DE LA DECISION D'APPEL","")
          local r,e=rpc("CASE_DECIDE_APPEAL",{
            id=c.id,appealId=a.id,result=result.v,reasoning=reasoning
          })
          message("APPEL",r and ("Decision d'appel: "..result.v) or e,r and palette.ok or palette.bad)
          if r then c=r end
        end
      end
    end
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
    c.hearings=c.hearings or {}
    c.orders=c.orders or {}
    c.appeals=c.appeals or {}
    c.visibility=c.visibility or "restricted"

    local actions={
      {text="Lire le dossier complet",id="read"},
      {text="Voir la chronologie du dossier",id="timeline"},
      {text="Audiences ("..#c.hearings..")",id="hearings"},
      {text="Ordonnances / mandats ("..#c.orders..")",id="orders"},
      {text="Appels ("..#c.appeals..")",id="appeals"},
      {text="Execution / sanctions / reparations",id="enforcement"},
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
    if allowed("visibilityWrite") then
      actions[#actions+1]={text="Changer la visibilite",id="visibility"}
    end
    if allowed("judgment") then
      actions[#actions+1]={text="Rediger un nouveau jugement",id="judgment"}
    end

    local a=menu(
      c.id.." - "..c.title,
      actions,
      "["..c.visibility.."] "..c.status.." | "..#c.facts.." faits | "..#c.hearings.." aud. | "..#c.appeals.." appel(s) | "..#c.judgments.." jug."
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
      local aps={}
      for _,ap in ipairs(c.appeals) do
        aps[#aps+1]=(ap.id or "?").." / "..(ap.appellant or "").." / "..(ap.status or "?")..
          (ap.result and (" -> "..ap.result) or "")
      end
      textPage(c.id,{
        {label="Affaire",text=c.title},
        {label="Statut",text=c.status.." / visibilite "..c.visibility},
        {label="Parties",text="Demandeur: "..(c.complainant or "-").."\nMis en cause: "..(c.accused or "-")},
        {label="Contexte",text=c.summary or ""},
        {label="Faits",text=table.concat(facts,"\n")},
        {label="Preuves",text=table.concat(ev,"\n")},
        {label="Articles cites",text=table.concat(c.citedArticles,"\n")},
        {label="Jugements",text=table.concat(js,"\n\n")},
        {label="Audiences / actes",text=tostring(#c.hearings).." audience(s) / "..tostring(#c.orders).." ordonnance(s)"},
        {label="Appels",text=#aps>0 and table.concat(aps,"\n") or "Aucun appel."},
        {label="Derniere mise a jour",text=c.updatedAt or c.createdAt or ""}
      })

    elseif a.id=="timeline" then
      caseTimelineScreen(c)

    elseif a.id=="hearings" then
      hearingsScreen(c)

    elseif a.id=="orders" then
      ordersScreen(c)

    elseif a.id=="appeals" then
      appealsScreen(c)

    elseif a.id=="enforcement" then
      enforcementsScreen("","","",c.id)

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

    elseif a.id=="visibility" then
      local v=menu("VISIBILITE DU DOSSIER",{
        {text="Public - visible aux lecteurs et affichages publics",v="public"},
        {text="Restreint - greffe, juges et administration",v="restricted"},
        {text="Scelle - reserve au circuit judiciaire",v="sealed"}
      },"Actuel: "..c.visibility)
      if v then
        local r,e=rpc("CASE_SET_VISIBILITY",{id=c.id,visibility=v.v})
        message("VISIBILITE",r and ("Dossier: "..r.visibility) or e,r and palette.ok or palette.bad)
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
        local postItems={
          {text="Revenir au dossier",id="back"},
          {text="Lire le jugement",id="read"},
          {text="Imprimer le jugement maintenant",id="print"}
        }
        if allowed("enforcementWrite") and latest then
          postItems[#postItems+1]={text="Creer le suivi d'execution de ce jugement",id="enforcement"}
        end
        local nextAction=menu("JUGEMENT ENREGISTRE",postItems,"Decision archivee avec les versions des articles citees.")
        if nextAction and nextAction.id=="read" and latest then
          judgmentDetails(r,latest)
        elseif nextAction and nextAction.id=="print" and latest then
          local ok,pages=printer.judgment(r,latest)
          message("IMPRESSION",ok and ("Jugement imprime: "..pages.." page(s).") or pages,ok and palette.ok or palette.bad)
        elseif nextAction and nextAction.id=="enforcement" and latest then
          createEnforcement(r.id,tostring(latest.id or ""))
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
      local visibilityChoice=menu("VISIBILITE INITIALE",{
        {text="Restreint (recommande pendant l'enquete)",v="restricted"},
        {text="Public",v="public"}
      })
      local r,e=rpc("CASE_CREATE",{
        title=title,complainant=complainant,accused=accused,summary=summary,
        visibility=visibilityChoice and visibilityChoice.v or "restricted"
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

local function stateDetails(st)
  while true do
    local full,err=rpc("STATE_GET",{id=st.id})
    if not full then message("ETAT",err,palette.bad);return end

    local actions={
      {text="Lire la fiche officielle",id="read"},
      {text="Voir les mesures d'execution / sanctions",id="enforcement"}
    }
    if allowed("institutionAdmin") then
      actions[#actions+1]={text="Modifier la fiche",id="edit"}
      actions[#actions+1]={text="Changer le statut",id="status"}
      actions[#actions+1]={text="Rattacher un terminal delegue",id="delegate"}
    end

    local a=menu(full.id.." - "..full.name,actions,
      "Statut "..tostring(full.status).." | representant "..tostring(full.representative or "-"))
    if not a then return end

    if a.id=="read" then
      textPage(full.id,{
        {label="Nom officiel",text=full.name or ""},
        {label="Nom court",text=full.shortName or ""},
        {label="Statut UNS",text=full.status or ""},
        {label="Gouvernement",text=full.government or ""},
        {label="Representant",text=full.representative or ""},
        {label="Notes",text=full.notes or ""},
        {label="Creation / mise a jour",text=(full.createdAt or "").." / "..(full.updatedAt or "")}
      })

    elseif a.id=="enforcement" then
      enforcementsScreen("","",full.id,"")

    elseif a.id=="edit" then
      local government=prompt("Gouvernement",full.government or "")
      local representative=prompt("Representant",full.representative or "")
      local notes=multi("NOTES OFFICIELLES",full.notes or "")
      local r,e=rpc("STATE_UPDATE",{
        id=full.id,government=government,representative=representative,notes=notes
      })
      message("ETAT",r and "Fiche mise a jour." or e,r and palette.ok or palette.bad)

    elseif a.id=="status" then
      local s=menu("STATUT DE L'ETAT",{
        {text="Candidat",v="candidate"},
        {text="Membre",v="member"},
        {text="Suspendu",v="suspended"},
        {text="Retire",v="withdrawn"},
        {text="Exclu",v="excluded"}
      })
      if s then
        local r,e=rpc("STATE_UPDATE",{id=full.id,status=s.v})
        message("ETAT",r and ("Nouveau statut: "..r.status) or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="delegate" then
      local clients,e=rpc("CLIENT_LIST",{})
      if not clients then
        message("TERMINAUX",e,palette.bad)
      else
        local items={}
        for _,cl in ipairs(clients) do
          if cl.role=="delegate" then
            items[#items+1]={
              text=cl.label.." / PC #"..tostring(cl.computerId)..
                (cl.stateId and (" / "..cl.stateId) or " / aucun Etat"),
              client=cl
            }
          end
        end
        if #items==0 then
          message("DELEGUES","Aucun terminal avec le role delegate. Appairez-en un depuis le serveur.",palette.warn)
        else
          local p=menu("RATTACHER UN DELEGUE",items,"Un terminal delegue represente un seul Etat pour les votes.")
          if p then
            local r,er=rpc("CLIENT_SET_STATE",{clientId=p.client.clientId,stateId=full.id})
            message("DELEGUE",r and (p.client.label.." -> "..full.name) or er,r and palette.ok or palette.bad)
          end
        end
      end
    end
  end
end

local function statesScreen(query,status)
  query=query or ""
  status=status or ""
  while true do
    local states,err=rpc("STATE_LIST",{query=query,status=status})
    if not states then message("ETATS",err,palette.bad);return end
    local items={}
    if allowed("institutionAdmin") then
      items[#items+1]={text="[+] Enregistrer un Etat",id="new"}
    end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer par statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"} end

    for _,st in ipairs(states) do
      items[#items+1]={text=st.id.."  "..st.name.."  ["..st.status.."]",state=st}
    end

    local p=menu("REGISTRE DES ETATS",items,#states.." Etat(s) visible(s)")
    if not p then return end

    if p.id=="new" then
      local name=prompt("Nom officiel")
      local shortName=prompt("Nom court",name)
      local government=prompt("Gouvernement / regime")
      local representative=prompt("Representant principal")
      local notes=multi("NOTES D'ADHESION / REGISTRE","")
      local st=menu("STATUT INITIAL",{
        {text="Candidat",v="candidate"},
        {text="Membre",v="member"}
      })
      local r,e=rpc("STATE_CREATE",{
        name=name,shortName=shortName,government=government,
        representative=representative,notes=notes,status=st and st.v or "candidate"
      })
      message("ETAT",r and ("Enregistre: "..r.id) or e,r and palette.ok or palette.bad)

    elseif p.id=="search" then
      query=prompt("Recherche Etat / representant",query)

    elseif p.id=="status" then
      local st=menu("FILTRER LES ETATS",{
        {text="Tous",v=""},{text="Candidats",v="candidate"},{text="Membres",v="member"},
        {text="Suspendus",v="suspended"},{text="Retires",v="withdrawn"},{text="Exclus",v="excluded"}
      })
      if st then status=st.v end

    elseif p.id=="reset" then
      query="";status=""

    elseif p.state then
      stateDetails(p.state)
    end
  end
end

local function thresholdLabel(v)
  local labels={
    simple_cast="Majorite simple des votes exprimes",
    absolute_members="Majorite absolue de tous les membres",
    two_thirds_cast="Deux tiers des votes exprimes",
    three_quarters_members="Trois quarts de tous les membres"
  }
  return labels[v] or tostring(v or "")
end

local function billTextSections(bill)
  local tally=bill.tally or {}
  local votes={}
  for stateId,v in pairs(bill.votes or {}) do
    votes[#votes+1]=(v.stateName or stateId).." : "..string.upper(v.choice or "?")..
      (v.at and (" / "..v.at) or "")
  end
  table.sort(votes)

  local typeText="Nouvel article"
  local targetText=""
  local proposalText=(bill.proposedTitle or "").."\n\n"..(bill.proposedBody or "")
  if bill.proposalType=="amendment" then
    typeText="Amendement"
    targetText=bill.targetRef or ""
  elseif bill.proposalType=="ratification_bundle" then
    typeText="Ratification groupee"
    targetText=table.concat(bill.targetRefs or {},"\n")
    proposalText="Activation des articles selectionnes sans modification de leur texte."
  end

  local promulgated=bill.enactedRefs and #bill.enactedRefs>0 and table.concat(bill.enactedRefs,"\n") or (bill.enactedRef or "-")

  return {
    {label="Proposition",text=bill.id.." / "..(bill.title or "")},
    {label="Etape",text=bill.stage or ""},
    {label="Type",text=typeText},
    {label="Articles cibles",text=targetText},
    {label="Resume",text=bill.summary or ""},
    {label="Texte propose",text=proposalText},
    {label="Classement",text=(bill.proposedBook or "").." / "..(bill.proposedSection or "")},
    {label="Regle de vote",text=thresholdLabel(bill.threshold)},
    {label="Tour de scrutin",text=tostring(bill.votingRound or 0)},
    {label="Quorum",text=tostring(tally.participation or 0).."/"..tostring(tally.eligible or 0)..
      " participants / minimum "..tostring(tally.quorumRequired or 0).." / "..(tally.quorumMet and "ATTEINT" or "NON ATTEINT")},
    {label="Resultats",text="Pour "..tostring(tally.yes or 0).." / Contre "..tostring(tally.no or 0)..
      " / Abstention "..tostring(tally.abstain or 0).." / Membres eligibles "..tostring(tally.eligible or 0)},
    {label="Votes par Etat",text=#votes>0 and table.concat(votes,"\n") or "Aucun vote enregistre."},
    {label="Sceau du scrutin",text=bill.resultSeal or "-"},
    {label="Promulgation",text=promulgated},
    {label="Sceau de promulgation",text=bill.enactmentSeal or "-"}
  }
end

local function chooseThreshold(current)
  local p=menu("REGLE DE MAJORITE",{
    {text="Majorite simple des votes exprimes",v="simple_cast"},
    {text="Majorite absolue de tous les membres",v="absolute_members"},
    {text="Deux tiers des votes exprimes",v="two_thirds_cast"},
    {text="Trois quarts de tous les membres",v="three_quarters_members"}
  },"Regle actuelle: "..thresholdLabel(current))
  return p and p.v or current or "simple_cast"
end

local function billDetails(id)
  while true do
    local bill,err=rpc("BILL_GET",{id=id})
    if not bill then message("PROPOSITION",err,palette.bad);return end

    local actions={
      {text="Lire la proposition et les resultats",id="read"},
      {text="Imprimer la proposition",id="print"}
    }

    if allowed("delegateVote") and bill.stage=="voting" then
      actions[#actions+1]={text="Voter au nom de mon Etat",id="vote"}
    end
    if allowed("legislature") and (bill.stage=="draft" or bill.stage=="debate") then
      actions[#actions+1]={text="Modifier le projet",id="edit"}
      actions[#actions+1]={text=bill.stage=="draft" and "Ouvrir le debat" or "Revenir au brouillon",id="stage"}
      actions[#actions+1]={text="Ouvrir le vote",id="open"}
    end
    if allowed("legislature") and bill.stage=="voting" then
      actions[#actions+1]={text="Clore et depouiller le vote",id="close"}
    end
    if allowed("legislature") and bill.stage=="no_quorum" then
      actions[#actions+1]={text="Ouvrir un nouveau tour de scrutin",id="reopen"}
    end
    if allowed("legislature") and bill.stage=="adopted" then
      actions[#actions+1]={text="Promulguer dans le Code",id="enact"}
    end
    if bill.enactedRef and bill.enactedRef~="" then
      actions[#actions+1]={text="Ouvrir l'article promulgue",id="law"}
    end

    local tally=bill.tally or {}
    local a=menu(bill.id.." - "..bill.title,actions,
      "["..bill.stage.."] Tour "..tostring(bill.votingRound or 0).." | Pour "..tostring(tally.yes or 0).." / Contre "..tostring(tally.no or 0).." / Quorum "..tostring(tally.participation or 0).."/"..tostring(tally.quorumRequired or 0))
    if not a then return end

    if a.id=="read" then
      textPage(bill.id,billTextSections(bill))

    elseif a.id=="print" then
      local ok,r=printer.bill(bill)
      message("IMPRESSION",ok and ("Proposition imprimee: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

    elseif a.id=="vote" then
      local v=menu("VOTE OFFICIEL",{
        {text="POUR",v="yes"},
        {text="CONTRE",v="no"},
        {text="ABSTENTION",v="abstain"}
      },"Le vote est rattache a l'Etat attribue a ce terminal.")
      if v then
        local r,e=rpc("BILL_VOTE",{id=bill.id,choice=v.v})
        message("VOTE",r and ("Vote enregistre. Pour "..r.tally.yes.." / Contre "..r.tally.no.." / Abst. "..r.tally.abstain) or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="edit" then
      local title=prompt("Titre de la proposition",bill.title)
      local summary=multi("RESUME / EXPOSE DES MOTIFS",bill.summary or "")
      local threshold=chooseThreshold(bill.threshold)
      local payload={id=bill.id,title=title,summary=summary,threshold=threshold}

      if bill.proposalType=="ratification_bundle" then
        local initial={}
        for _,ref in ipairs(bill.targetRefs or {}) do initial[#initial+1]=ref end
        local picked=lawBasketBrowser(initial) or {}
        local refs={}
        for _,law in ipairs(picked) do refs[#refs+1]=law.ref end
        payload.targetRefs=refs
      else
        payload.proposedTitle=prompt("Titre de l'article",bill.proposedTitle)
        payload.proposedBody=multi("TEXTE PROPOSE",bill.proposedBody or "")
      end

      local r,e=rpc("BILL_EDIT",payload)
      message("PROPOSITION",r and "Projet mis a jour." or e,r and palette.ok or palette.bad)

    elseif a.id=="stage" then
      local nextStage=bill.stage=="draft" and "debate" or "draft"
      local r,e=rpc("BILL_SET_STAGE",{id=bill.id,stage=nextStage})
      message("ASSEMBLEE",r and ("Etape: "..r.stage) or e,r and palette.ok or palette.bad)

    elseif a.id=="open" then
      local r,e=rpc("BILL_OPEN_VOTE",{id=bill.id})
      message("ASSEMBLEE",r and ("Vote officiellement ouvert / tour "..tostring(r.votingRound or 1)) or e,r and palette.ok or palette.bad)

    elseif a.id=="reopen" then
      local r,e=rpc("BILL_OPEN_VOTE",{id=bill.id})
      message("ASSEMBLEE",r and ("Nouveau tour ouvert: "..tostring(r.votingRound or "?")) or e,r and palette.ok or palette.bad)

    elseif a.id=="close" then
      local confirm=menu("CLOTURER LE VOTE",{
        {text="Clore maintenant et calculer le resultat",id="yes"},
        {text="Annuler",id="no"}
      },"La regle appliquee sera: "..thresholdLabel(bill.threshold))
      if confirm and confirm.id=="yes" then
        local r,e=rpc("BILL_CLOSE",{id=bill.id})
        local resultText=e
        local resultColor=palette.bad
        if r then
          if r.result=="adopted" then resultText="PROPOSITION ADOPTEE";resultColor=palette.ok
          elseif r.result=="no_quorum" then resultText="SCRUTIN INVALIDE: QUORUM NON ATTEINT";resultColor=palette.warn
          else resultText="PROPOSITION REJETEE";resultColor=palette.warn end
        end
        message("RESULTAT",resultText,resultColor)
      end

    elseif a.id=="enact" then
      local confirm=menu("PROMULGATION",{
        {text="Promulguer et appliquer au Code",id="yes"},
        {text="Annuler",id="no"}
      },"Cette operation creera/modifiera une loi active et sera journalisee.")
      if confirm and confirm.id=="yes" then
        local r,e=rpc("BILL_ENACT",{id=bill.id})
        local promText=e
        if r then
          if r.enactedRefs and #r.enactedRefs>1 then promText=tostring(#r.enactedRefs).." articles ratifies et actives."
          else promText="Promulgue: "..tostring(r.enactedRef) end
        end
        message("PROMULGATION",promText,r and palette.ok or palette.bad)
      end

    elseif a.id=="law" then
      viewLaw(bill.enactedRef)
    end
  end
end

local function billsScreen(query,stage)
  query=query or ""
  stage=stage or ""
  while true do
    local bills,err=rpc("BILL_LIST",{query=query,stage=stage})
    if not bills then message("ASSEMBLEE",err,palette.bad);return end

    local items={}
    if allowed("legislature") then items[#items+1]={text="[+] Deposer une proposition de loi",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[E] Filtrer par etape"..(stage~="" and (" ["..stage.."]") or ""),id="stage"}
    if query~="" or stage~="" then items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"} end

    for _,bill in ipairs(bills) do
      items[#items+1]={text=bill.id.."  "..bill.title.."  ["..bill.stage.."]",bill=bill}
    end

    local p=menu("ASSEMBLEE / PROPOSITIONS",items,#bills.." proposition(s)")
    if not p then return end

    if p.id=="new" then
      local kind=menu("TYPE DE PROPOSITION",{
        {text="Creer un nouvel article",v="new_law"},
        {text="Modifier un article existant",v="amendment"},
        {text="Ratifier / activer plusieurs articles existants",v="ratification_bundle"}
      })

      if kind then
        local target=nil
        local targetRefs={}
        local proposedTitle=""
        local proposedBody=""
        local proposedBook=""
        local proposedSection=""
        local canContinue=true

        if kind.v=="amendment" then
          local law=referenceBrowser({mode="browse",pick=true})
          if law then
            target=rpc("LAW_GET",{ref=law.ref})
            if target then
              proposedTitle=target.title or ""
              proposedBody=target.body or ""
              proposedBook=target.book or ""
              proposedSection=target.section or ""
            end
          end
          if not target then
            message("PROPOSITION","Creation annulee: article cible non selectionne.",palette.warn)
            canContinue=false
          end

        elseif kind.v=="ratification_bundle" then
          local picked=lawBasketBrowser({}) or {}
          for _,law in ipairs(picked) do targetRefs[#targetRefs+1]=law.ref end
          if #targetRefs==0 then
            message("PROPOSITION","Selection vide: aucun article a ratifier.",palette.warn)
            canContinue=false
          end

        else
          local books=rpc("LAW_BOOKS",{}) or {}
          local bookItems={}
          for _,b in ipairs(books) do bookItems[#bookItems+1]={text=bookLabel(b),book=b.name} end
          local bp=menu("LIVRE DU FUTUR ARTICLE",bookItems)
          if bp then proposedBook=bp.book end
        end

        if canContinue then
          local title=prompt("Titre de la proposition")
          local summary=multi("EXPOSE DES MOTIFS","")

          if kind.v~="ratification_bundle" then
            proposedTitle=prompt("Titre juridique propose",proposedTitle)
            proposedSection=prompt("Section",proposedSection)
            proposedBody=multi("TEXTE JURIDIQUE PROPOSE",proposedBody)
          end

          local threshold=chooseThreshold("simple_cast")
          local r,e=rpc("BILL_CREATE",{
            title=title,summary=summary,proposalType=kind.v,
            targetRef=target and target.ref or "",targetRefs=targetRefs,
            proposedTitle=proposedTitle,proposedBody=proposedBody,
            proposedBook=proposedBook,proposedSection=proposedSection,
            threshold=threshold
          })
          message("PROPOSITION",r and ("Deposee: "..r.id) or e,r and palette.ok or palette.bad)
        end
      end
    elseif p.id=="search" then
      query=prompt("Recherche proposition",query)

    elseif p.id=="stage" then
      local e=menu("ETAPE LEGISLATIVE",{
        {text="Toutes",v=""},{text="Brouillons",v="draft"},{text="En debat",v="debate"},
        {text="Vote ouvert",v="voting"},{text="Sans quorum",v="no_quorum"},
        {text="Adoptees",v="adopted"},{text="Rejetees",v="rejected"},
        {text="Promulguees",v="enacted"}
      })
      if e then stage=e.v end

    elseif p.id=="reset" then
      query="";stage=""

    elseif p.bill then
      billDetails(p.bill.id)
    end
  end
end

local function resolutionTypeLabel(v)
  local labels={
    general="Resolution generale",sanctions="Sanctions / mesures coercitives",
    peace_security="Paix et securite",membership="Adhesion / statut d'un Etat",
    humanitarian="Humanitaire",emergency="Urgence internationale",
    investigation="Enquete / mission d'etablissement des faits",ceasefire="Cessez-le-feu",
    observer_mission="Mission d'observation",economic="Mesure economique",other="Autre"
  }
  return labels[v] or tostring(v or "")
end

local function chooseResolutionType(current)
  local p=menu("TYPE DE RESOLUTION",{
    {text="Resolution generale",v="general"},
    {text="Sanctions / mesures coercitives",v="sanctions"},
    {text="Paix et securite",v="peace_security"},
    {text="Adhesion / statut d'un Etat",v="membership"},
    {text="Humanitaire",v="humanitarian"},
    {text="Urgence internationale",v="emergency"},
    {text="Enquete / mission d'etablissement des faits",v="investigation"},
    {text="Cessez-le-feu",v="ceasefire"},
    {text="Mission d'observation",v="observer_mission"},
    {text="Mesure economique",v="economic"},
    {text="Autre",v="other"}
  },"Actuel: "..resolutionTypeLabel(current))
  return p and p.v or current or "general"
end

local function chooseResolutionTarget(current)
  local states,err=rpc("STATE_LIST",{})
  if not states then message("ETATS",err,palette.bad);return current or "" end
  local items={{text="[AUCUN ETAT CIBLE]",id=""}}
  for _,st in ipairs(states) do
    items[#items+1]={text=st.id.."  "..st.name.."  ["..st.status.."]",id=st.id}
  end
  local p=menu("ETAT CIBLE",items,"Optionnel selon la resolution.")
  return p and p.id or current or ""
end

local function chooseResolutionEnforcementType(current)
  local p=menu("MESURE D'EXECUTION",{
    {text="Amende / paiement",v="fine"},
    {text="Restitution",v="restitution"},
    {text="Indemnisation",v="compensation"},
    {text="Embargo",v="embargo"},
    {text="Embargo militaire",v="military_embargo"},
    {text="Gel d'avoirs",v="asset_freeze"},
    {text="Restriction commerciale",v="trade_restriction"},
    {text="Suspension de droits",v="suspension"},
    {text="Ordre de cessation",v="cease"},
    {text="Inspection internationale",v="inspection"},
    {text="Zone demilitarisee",v="demilitarized_zone"},
    {text="Autre",v="other"}
  },"Actuel: "..tostring(current or ""))
  return p and p.v or current or "other"
end

local function resolutionSections(r)
  local tally=r.tally or {}
  local votes={}
  for stateId,v in pairs(r.votes or {}) do
    votes[#votes+1]=(v.stateName or stateId).." : "..string.upper(v.choice or "?")..
      (v.at and (" / "..v.at) or "")
  end
  table.sort(votes)

  return {
    {label="Resolution",text=r.id.." / "..(r.title or "")},
    {label="Type",text=resolutionTypeLabel(r.resolutionType)},
    {label="Etape",text=r.stage or ""},
    {label="Etat cible",text=r.targetStateId or "-"},
    {label="Dossier lie",text=r.linkedCaseId or "-"},
    {label="Resume",text=r.summary or ""},
    {label="Texte integral",text=r.body or ""},
    {label="Regle de vote",text=thresholdLabel(r.threshold)},
    {label="Tour / quorum",text="Tour "..tostring(r.votingRound or 0).." / "..tostring(tally.participation or 0)..
      "/"..tostring(tally.eligible or 0).." participants / minimum "..tostring(tally.quorumRequired or 0)..
      " / "..(tally.quorumMet and "ATTEINT" or "NON ATTEINT")},
    {label="Resultat",text="Pour "..tostring(tally.yes or 0).." / Contre "..tostring(tally.no or 0)..
      " / Abstention "..tostring(tally.abstain or 0).." / "..tostring(r.result or "-")},
    {label="Votes par Etat",text=#votes>0 and table.concat(votes,"\n") or "Aucun vote."},
    {label="Sceau du scrutin",text=r.resultSeal or "-"},
    {label="Execution automatique",text=r.createsEnforcement and
      ((r.enforcementType or "other").." / "..(r.enforcementTerms or "")..
      ((r.enforcementAmount and r.enforcementAmount~="") and (" / "..r.enforcementAmount) or "")..
      ((r.enforcementDeadline and r.enforcementDeadline~="") and (" / echeance "..r.enforcementDeadline) or ""))
      or "Aucune mesure automatique"},
    {label="Mesure creee",text=r.enforcementId or "-"},
    {label="Sceau d'execution",text=r.executionSeal or "-"}
  }
end

local function resolutionDetails(id)
  while true do
    local r,err=rpc("RESOLUTION_GET",{id=id})
    if not r then message("RESOLUTION",err,palette.bad);return end
    local tally=r.tally or {}

    local actions={
      {text="Lire la resolution et le scrutin",id="read"},
      {text="Imprimer la resolution",id="print"}
    }

    if allowed("resolutionVote") and r.stage=="voting" then
      actions[#actions+1]={text="Voter au nom de mon Etat",id="vote"}
    end

    if allowed("resolutionWrite") and (r.stage=="draft" or r.stage=="debate") then
      actions[#actions+1]={text="Modifier le projet",id="edit"}
      actions[#actions+1]={text=r.stage=="draft" and "Ouvrir le debat" or "Revenir au brouillon",id="stage"}
      actions[#actions+1]={text="Ouvrir le vote",id="open"}
    end

    if allowed("resolutionWrite") and r.stage=="voting" then
      actions[#actions+1]={text="Clore et depouiller le vote",id="close"}
    end

    if allowed("resolutionWrite") and r.stage=="no_quorum" then
      actions[#actions+1]={text="Ouvrir un nouveau tour de scrutin",id="reopen"}
    end

    if allowed("resolutionWrite") and r.stage=="adopted" then
      actions[#actions+1]={text="Executer / publier la resolution",id="execute"}
    end

    if r.enforcementId and r.enforcementId~="" then
      actions[#actions+1]={text="Ouvrir la mesure d'execution associee",id="enforcement"}
    end

    local a=menu(r.id.." - "..r.title,actions,
      "["..r.stage.."] "..resolutionTypeLabel(r.resolutionType).." | Pour "..tostring(tally.yes or 0)..
      " / Contre "..tostring(tally.no or 0))
    if not a then return end

    if a.id=="read" then
      textPage(r.id,resolutionSections(r))

    elseif a.id=="print" then
      local ok,pages=printer.resolution(r)
      message("IMPRESSION",ok and ("Resolution imprimee: "..pages.." page(s).") or pages,ok and palette.ok or palette.bad)

    elseif a.id=="vote" then
      local v=menu("VOTE OFFICIEL",{
        {text="POUR",v="yes"},{text="CONTRE",v="no"},{text="ABSTENTION",v="abstain"}
      },"Une voix par Etat.")
      if v then
        local out,e=rpc("RESOLUTION_VOTE",{id=r.id,choice=v.v})
        message("VOTE",out and ("Vote enregistre. Pour "..out.tally.yes.." / Contre "..out.tally.no) or e,out and palette.ok or palette.bad)
      end

    elseif a.id=="edit" then
      local title=prompt("Titre",r.title)
      local typ=chooseResolutionType(r.resolutionType)
      local target=chooseResolutionTarget(r.targetStateId)
      local linkedCase=prompt("Dossier lie CASE-... (optionnel)",r.linkedCaseId or "")
      local summary=multi("EXPOSE / RESUME",r.summary or "")
      local body=multi("TEXTE DE LA RESOLUTION",r.body or "")
      local threshold=chooseThreshold(r.threshold)

      local createChoice=menu("EXECUTION AUTOMATIQUE",{
        {text="Conserver / activer une mesure d'execution",v=true},
        {text="Aucune mesure automatique",v=false}
      },r.createsEnforcement and "Actuellement activee" or "Actuellement desactivee")
      local creates=createChoice and createChoice.v or false
      local enforcementType=r.enforcementType or ""
      local enforcementTerms=r.enforcementTerms or ""
      local enforcementAmount=r.enforcementAmount or ""
      local enforcementDeadline=r.enforcementDeadline or ""

      if creates then
        enforcementType=chooseResolutionEnforcementType(enforcementType)
        enforcementTerms=multi("CONDITIONS D'EXECUTION",enforcementTerms)
        enforcementAmount=prompt("Montant / valeur (optionnel)",enforcementAmount)
        enforcementDeadline=prompt("Echeance (optionnel)",enforcementDeadline)
      end

      local out,e=rpc("RESOLUTION_EDIT",{
        id=r.id,title=title,resolutionType=typ,targetStateId=target,linkedCaseId=linkedCase,
        summary=summary,body=body,threshold=threshold,createsEnforcement=creates,
        enforcementType=enforcementType,enforcementTerms=enforcementTerms,
        enforcementAmount=enforcementAmount,enforcementDeadline=enforcementDeadline
      })
      message("RESOLUTION",out and "Projet mis a jour." or e,out and palette.ok or palette.bad)

    elseif a.id=="stage" then
      local nextStage=r.stage=="draft" and "debate" or "draft"
      local out,e=rpc("RESOLUTION_SET_STAGE",{id=r.id,stage=nextStage})
      message("RESOLUTION",out and ("Etape: "..out.stage) or e,out and palette.ok or palette.bad)

    elseif a.id=="open" or a.id=="reopen" then
      local out,e=rpc("RESOLUTION_OPEN_VOTE",{id=r.id})
      message("RESOLUTION",out and ("Scrutin ouvert / tour "..tostring(out.votingRound or "?")) or e,out and palette.ok or palette.bad)

    elseif a.id=="close" then
      local confirm=menu("CLOTURER LE SCRUTIN",{
        {text="Clore et calculer le resultat",id="yes"},{text="Annuler",id="no"}
      },thresholdLabel(r.threshold))
      if confirm and confirm.id=="yes" then
        local out,e=rpc("RESOLUTION_CLOSE",{id=r.id})
        local msg=e
        local col=palette.bad
        if out then
          if out.result=="adopted" then msg="RESOLUTION ADOPTEE";col=palette.ok
          elseif out.result=="no_quorum" then msg="QUORUM NON ATTEINT";col=palette.warn
          else msg="RESOLUTION REJETEE";col=palette.warn end
        end
        message("RESULTAT",msg,col)
      end

    elseif a.id=="execute" then
      local confirm=menu("EXECUTER LA RESOLUTION",{
        {text="Publier et executer maintenant",id="yes"},{text="Annuler",id="no"}
      },"Une eventuelle mesure ENF sera creee automatiquement.")
      if confirm and confirm.id=="yes" then
        local out,e=rpc("RESOLUTION_EXECUTE",{id=r.id})
        message("RESOLUTION",out and ("Execution enregistree"..(out.enforcementId and (" / "..out.enforcementId) or "")) or e,out and palette.ok or palette.bad)
      end

    elseif a.id=="enforcement" then
      enforcementsScreen(r.enforcementId,"","","")
    end
  end
end

local function resolutionsScreen(query,stage)
  query=query or ""
  stage=stage or ""

  while true do
    local rows,err=rpc("RESOLUTION_LIST",{query=query,stage=stage})
    if not rows then message("RESOLUTIONS",err,palette.bad);return end

    local items={}
    if allowed("resolutionWrite") then items[#items+1]={text="[+] Deposer une nouvelle resolution",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[E] Filtrer par etape"..(stage~="" and (" ["..stage.."]") or ""),id="stage"}
    if query~="" or stage~="" then items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"} end

    for _,r in ipairs(rows) do
      items[#items+1]={text=r.id.."  "..r.title.."  ["..r.stage.."]",resolution=r}
    end

    local p=menu("RESOLUTIONS DE L'UNION",items,#rows.." resolution(s)")
    if not p then return end

    if p.id=="new" then
      local title=prompt("Titre de la resolution")
      local typ=chooseResolutionType("general")
      local target=chooseResolutionTarget("")
      local linkedCase=prompt("Dossier lie CASE-... (optionnel)")
      local summary=multi("EXPOSE / RESUME","")
      local body=multi("TEXTE DE LA RESOLUTION","")
      local threshold=chooseThreshold("simple_cast")

      local createChoice=menu("CREER UNE MESURE D'EXECUTION SI ADOPTEE ?",{
        {text="Non",v=false},{text="Oui",v=true}
      },"Particulierement utile pour sanctions, reparations et inspections.")
      local creates=createChoice and createChoice.v or false
      local enforcementType=""
      local enforcementTerms=""
      local enforcementAmount=""
      local enforcementDeadline=""
      if creates then
        enforcementType=chooseResolutionEnforcementType("other")
        enforcementTerms=multi("CONDITIONS D'EXECUTION","")
        enforcementAmount=prompt("Montant / valeur (optionnel)")
        enforcementDeadline=prompt("Echeance (optionnel)")
      end

      local out,e=rpc("RESOLUTION_CREATE",{
        title=title,resolutionType=typ,targetStateId=target,linkedCaseId=linkedCase,
        summary=summary,body=body,threshold=threshold,createsEnforcement=creates,
        enforcementType=enforcementType,enforcementTerms=enforcementTerms,
        enforcementAmount=enforcementAmount,enforcementDeadline=enforcementDeadline
      })
      message("RESOLUTION",out and ("Deposee: "..out.id) or e,out and palette.ok or palette.bad)

    elseif p.id=="search" then
      query=prompt("Recherche resolution",query)

    elseif p.id=="stage" then
      local st=menu("ETAPE DE LA RESOLUTION",{
        {text="Toutes",v=""},{text="Brouillons",v="draft"},{text="En debat",v="debate"},
        {text="Vote ouvert",v="voting"},{text="Sans quorum",v="no_quorum"},
        {text="Adoptees",v="adopted"},{text="Rejetees",v="rejected"},
        {text="Executees",v="executed"}
      })
      if st then stage=st.v end

    elseif p.id=="reset" then
      query="";stage=""

    elseif p.resolution then
      resolutionDetails(p.resolution.id)
    end
  end
end

local function stateBasketBrowser(initial)
  local selected={}
  for _,id in ipairs(initial or {}) do selected[id]=true end

  while true do
    local states,err=rpc("STATE_LIST",{})
    if not states then message("ETATS",err,palette.bad);return nil end

    local items={
      {text="[OK] Valider les Etats parties",id="done"},
      {text="[M] Selectionner tous les Etats membres",id="members"},
      {text="[X] Vider la selection",id="clear"}
    }
    local count=0
    for _,st in ipairs(states) do
      if selected[st.id] then count=count+1 end
      items[#items+1]={
        text=(selected[st.id] and "[X] " or "[ ] ")..st.id.." "..st.name.." ["..st.status.."]",
        state=st
      }
    end

    local p=menu("ETATS PARTIES",items,count.." Etat(s) selectionne(s)")
    if not p then
      local out={}
      for _,st in ipairs(states) do if selected[st.id] then out[#out+1]=st.id end end
      return out
    end

    if p.id=="done" then
      local out={}
      for _,st in ipairs(states) do if selected[st.id] then out[#out+1]=st.id end end
      return out

    elseif p.id=="members" then
      for _,st in ipairs(states) do if st.status=="member" then selected[st.id]=true end end

    elseif p.id=="clear" then
      selected={}

    elseif p.state then
      if selected[p.state.id] then selected[p.state.id]=nil else selected[p.state.id]=true end
    end
  end
end

local function treatyTypeLabel(v)
  local labels={
    bilateral="Accord bilateral",multilateral="Traite multilateral",
    defense="Defense / alliance",trade="Commerce",border="Frontiere",
    ceasefire="Cessez-le-feu",non_aggression="Non-agression",other="Autre"
  }
  return labels[v] or tostring(v or "")
end

local function chooseTreatyType(current)
  local p=menu("TYPE DE TRAITE",{
    {text="Accord bilateral",v="bilateral"},
    {text="Traite multilateral",v="multilateral"},
    {text="Defense / alliance",v="defense"},
    {text="Commerce",v="trade"},
    {text="Frontiere",v="border"},
    {text="Cessez-le-feu",v="ceasefire"},
    {text="Non-agression",v="non_aggression"},
    {text="Autre",v="other"}
  },"Actuel: "..treatyTypeLabel(current))
  return p and p.v or current or "other"
end

local function treatySections(t)
  local status=t.signatureStatus or {}
  local sigs={}
  for stateId,sig in pairs(t.signatures or {}) do
    sigs[#sigs+1]=(sig.stateName or stateId).." / "..(sig.at or "").." / "..(sig.seal or "-")
  end
  table.sort(sigs)

  local history={}
  for _,h in ipairs(t.history or {}) do
    history[#history+1]="v"..tostring(h.version or "?").." / "..tostring(h.archivedAt or "").." / "..tostring(h.archivedBy or "")
  end

  return {
    {label="Traite",text=t.id.." / "..(t.title or "")},
    {label="Type / version",text=treatyTypeLabel(t.treatyType).." / v"..tostring(t.version or 1)},
    {label="Statut",text=t.stage or ""},
    {label="Etats parties",text=table.concat(t.parties or {},"\n")},
    {label="Signatures",text=tostring(status.signed or 0).."/"..tostring(status.required or 0)..
      (status.complete and " / COMPLET" or " / incomplet")},
    {label="Resume",text=t.summary or ""},
    {label="Texte integral",text=t.body or ""},
    {label="Sceau du texte",text=t.signatureTextSeal or "-"},
    {label="Signatures officielles",text=#sigs>0 and table.concat(sigs,"\n") or "Aucune signature."},
    {label="Entree en vigueur",text=(t.effectiveAt or "-").." / sceau "..(t.activationSeal or "-")},
    {label="Fin du traite",text=(t.terminationReason or "-")..(t.terminatedAt and (" / "..t.terminatedAt) or "")},
    {label="Historique des versions",text=#history>0 and table.concat(history,"\n") or "Version initiale."}
  }
end

local function treatyDetails(id)
  while true do
    local t,err=rpc("TREATY_GET",{id=id})
    if not t then message("TRAITE",err,palette.bad);return end

    local sig=t.signatureStatus or {}
    local actions={
      {text="Lire le traite integral",id="read"},
      {text="Imprimer le traite",id="print"}
    }

    if allowed("treatySign") and t.stage=="signing" then
      actions[#actions+1]={text="Signer au nom de mon Etat",id="sign"}
    end

    if allowed("diplomacy") and t.stage=="draft" then
      actions[#actions+1]={text="Modifier le projet",id="edit"}
      actions[#actions+1]={text="Ouvrir les signatures",id="open"}
    end

    if allowed("diplomacy") and t.stage=="ready" then
      actions[#actions+1]={text="Faire entrer le traite en vigueur",id="activate"}
    end

    if allowed("diplomacy") and t.stage=="in_force" then
      actions[#actions+1]={text="Mettre fin au traite",id="terminate"}
    end

    local a=menu(t.id.." - "..t.title,actions,
      "["..t.stage.."] signatures "..tostring(sig.signed or 0).."/"..tostring(sig.required or 0).." / v"..tostring(t.version or 1))
    if not a then return end

    if a.id=="read" then
      textPage(t.id,treatySections(t))

    elseif a.id=="print" then
      local ok,r=printer.treaty(t)
      message("IMPRESSION",ok and ("Traite imprime: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

    elseif a.id=="sign" then
      local confirm=menu("SIGNATURE OFFICIELLE",{
        {text="Signer ce texte au nom de mon Etat",id="yes"},
        {text="Annuler",id="no"}
      },"Le serveur verifiera que votre Etat fait partie des signataires.")
      if confirm and confirm.id=="yes" then
        local r,e=rpc("TREATY_SIGN",{id=t.id})
        message("SIGNATURE",r and "Signature officielle enregistree." or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="edit" then
      local title=prompt("Titre du traite",t.title)
      local treatyType=chooseTreatyType(t.treatyType)
      local summary=multi("RESUME / PREAMBULE",t.summary or "")
      local parties=stateBasketBrowser(t.parties or {}) or t.parties
      local body=multi("TEXTE DU TRAITE",t.body or "")
      local r,e=rpc("TREATY_EDIT",{
        id=t.id,title=title,treatyType=treatyType,summary=summary,parties=parties,body=body
      })
      message("TRAITE",r and ("Version "..r.version.." enregistree.") or e,r and palette.ok or palette.bad)

    elseif a.id=="open" then
      local confirm=menu("OUVRIR LES SIGNATURES",{
        {text="Figer ce texte et ouvrir les signatures",id="yes"},
        {text="Annuler",id="no"}
      },"Apres ouverture, le texte ne pourra plus etre modifie.")
      if confirm and confirm.id=="yes" then
        local r,e=rpc("TREATY_OPEN_SIGNATURE",{id=t.id})
        message("TRAITE",r and ("Signatures ouvertes / sceau "..tostring(r.signatureTextSeal)) or e,r and palette.ok or palette.bad)
      end

    elseif a.id=="activate" then
      local r,e=rpc("TREATY_ACTIVATE",{id=t.id})
      message("TRAITE",r and "Traite entre en vigueur et archive avec son sceau." or e,r and palette.ok or palette.bad)

    elseif a.id=="terminate" then
      local reason=multi("MOTIF DE FIN DU TRAITE","")
      local r,e=rpc("TREATY_TERMINATE",{id=t.id,reason=reason})
      message("TRAITE",r and "Fin du traite enregistree." or e,r and palette.ok or palette.bad)
    end
  end
end

local function treatiesScreen(query,stage,stateId)
  query=query or ""
  stage=stage or ""
  stateId=stateId or ""

  while true do
    local treaties,err=rpc("TREATY_LIST",{query=query,stage=stage,stateId=stateId})
    if not treaties then message("TRAITES",err,palette.bad);return end

    local items={}
    if allowed("diplomacy") then items[#items+1]={text="[+] Rediger un nouveau traite",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer par statut"..(stage~="" and (" ["..stage.."]") or ""),id="stage"}
    if query~="" or stage~="" then items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"} end

    for _,t in ipairs(treaties) do
      items[#items+1]={
        text=t.id.."  "..t.title.."  ["..t.stage.."]",
        treaty=t
      }
    end

    local p=menu("TRAITES / DIPLOMATIE",items,#treaties.." traite(s)")
    if not p then return end

    if p.id=="new" then
      local title=prompt("Titre du traite")
      local treatyType=chooseTreatyType("other")
      local parties=stateBasketBrowser({})
      if not parties or #parties<2 then
        message("TRAITE","Il faut selectionner au moins deux Etats parties.",palette.warn)
      else
        local summary=multi("RESUME / PREAMBULE","")
        local body=multi("TEXTE DU TRAITE","")
        local r,e=rpc("TREATY_CREATE",{
          title=title,treatyType=treatyType,parties=parties,summary=summary,body=body
        })
        message("TRAITE",r and ("Projet cree: "..r.id) or e,r and palette.ok or palette.bad)
      end

    elseif p.id=="search" then
      query=prompt("Recherche traite",query)

    elseif p.id=="stage" then
      local st=menu("STATUT DU TRAITE",{
        {text="Tous",v=""},{text="Brouillons",v="draft"},{text="Signatures ouvertes",v="signing"},
        {text="Pret a entrer en vigueur",v="ready"},{text="En vigueur",v="in_force"},
        {text="Termines",v="terminated"}
      })
      if st then stage=st.v end

    elseif p.id=="reset" then
      query="";stage=""

    elseif p.treaty then
      treatyDetails(p.treaty.id)
    end
  end
end

local function enforcementTypeLabel(v)
  local labels={
    fine="Amende / paiement",restitution="Restitution",compensation="Indemnisation",
    embargo="Embargo",military_embargo="Embargo militaire",asset_freeze="Gel d'avoirs",
    trade_restriction="Restriction commerciale",suspension="Suspension de droits",
    cease="Ordre de cessation",inspection="Inspection internationale",
    demilitarized_zone="Zone demilitarisee",other="Autre mesure"
  }
  return labels[v] or tostring(v or "")
end

local function chooseEnforcementType(current)
  local p=menu("TYPE DE MESURE",{
    {text="Amende / paiement",v="fine"},
    {text="Restitution",v="restitution"},
    {text="Indemnisation",v="compensation"},
    {text="Embargo",v="embargo"},
    {text="Embargo militaire",v="military_embargo"},
    {text="Gel d'avoirs",v="asset_freeze"},
    {text="Restriction commerciale",v="trade_restriction"},
    {text="Suspension de droits",v="suspension"},
    {text="Ordre de cessation",v="cease"},
    {text="Inspection internationale",v="inspection"},
    {text="Zone demilitarisee",v="demilitarized_zone"},
    {text="Autre mesure",v="other"}
  },"Actuel: "..enforcementTypeLabel(current))
  return p and p.v or current or "other"
end

local function chooseStateTarget()
  local states,err=rpc("STATE_LIST",{})
  if not states then message("ETATS",err,palette.bad);return nil end
  local items={}
  for _,st in ipairs(states) do
    items[#items+1]={text=st.id.."  "..st.name.."  ["..st.status.."]",state=st}
  end
  local p=menu("ETAT CIBLE",items,"Selectionnez l'Etat concerne.")
  return p and p.state or nil
end

createEnforcement=function(prefillCaseId,prefillJudgmentId)
  local targetKind=menu("CIBLE DE LA MESURE",{
    {text="Etat membre / candidat",v="state"},
    {text="Personne",v="person"},
    {text="Organisation / entreprise",v="organization"},
    {text="Autre",v="other"}
  })
  if not targetKind then return end

  local targetStateId=""
  local targetName=""
  if targetKind.v=="state" then
    local st=chooseStateTarget()
    if not st then return end
    targetStateId=st.id
    targetName=st.name
  else
    targetName=prompt("Nom de la cible")
  end

  local typ=chooseEnforcementType("other")
  local summary=prompt("Objet court de la mesure")
  local terms=multi("CONDITIONS / OBLIGATIONS D'EXECUTION","")
  local amount=prompt("Montant / valeur (optionnel)")
  local deadline=prompt("Echeance (optionnel)")
  local caseId=prefillCaseId or prompt("Dossier lie CASE-... (optionnel)")
  local judgmentId=prefillJudgmentId or prompt("Jugement lie (optionnel)")
  local visibility=menu("VISIBILITE",{
    {text="Restreinte au circuit institutionnel",v="restricted"},
    {text="Publique",v="public"}
  })

  local r,e=rpc("ENFORCEMENT_CREATE",{
    caseId=caseId or "",judgmentId=judgmentId or "",
    targetType=targetKind.v,targetStateId=targetStateId,targetName=targetName,
    enforcementType=typ,summary=summary,terms=terms,amount=amount,deadline=deadline,
    visibility=visibility and visibility.v or "restricted"
  })
  message("EXECUTION",r and ("Mesure creee: "..r.id) or e,r and palette.ok or palette.bad)
  return r
end

local function enforcementSections(e)
  local progress={}
  for _,row in ipairs(e.progress or {}) do
    progress[#progress+1]="#"..tostring(row.id or "?").." / "..(row.at or "").." / "..(row.by or "?")..
      "\n"..(row.note or "")..
      ((row.reference and row.reference~="") and ("\nReference: "..row.reference) or "")..
      "\nSceau: "..(row.seal or "-")
  end
  local history={}
  for _,row in ipairs(e.statusHistory or {}) do
    history[#history+1]=(row.at or "").." / "..(row.from or "?").." -> "..(row.to or "?")..
      ((row.reason and row.reason~="") and (" / "..row.reason) or "")..
      "\nSceau: "..(row.seal or "-")
  end

  return {
    {label="Mesure",text=(e.id or "").." / "..enforcementTypeLabel(e.enforcementType)},
    {label="Statut / visibilite",text=(e.status or "").." / "..(e.visibility or "restricted")},
    {label="Cible",text=(e.targetName or "")..((e.targetStateId and e.targetStateId~="") and (" / "..e.targetStateId) or "")},
    {label="Dossier / jugement",text=(e.caseId or "-").." / "..(e.judgmentId or "-")},
    {label="Objet",text=e.summary or ""},
    {label="Conditions",text=e.terms or ""},
    {label="Montant",text=e.amount or "-"},
    {label="Echeance",text=e.deadline or "-"},
    {label="Ordonnance",text=(e.createdBy or "").." / "..(e.createdAt or "")},
    {label="Sceau initial",text=e.seal or "-"},
    {label="Suivi d'execution",text=#progress>0 and table.concat(progress,"\n\n") or "Aucun compte rendu."},
    {label="Historique de statut",text=#history>0 and table.concat(history,"\n\n") or "Aucun changement."}
  }
end

local function enforcementDetails(id)
  while true do
    local e,err=rpc("ENFORCEMENT_GET",{id=id})
    if not e then message("EXECUTION",err,palette.bad);return end

    local actions={
      {text="Lire la fiche complete",id="read"},
      {text="Imprimer la mesure",id="print"}
    }
    if e.caseId and e.caseId~="" then actions[#actions+1]={text="Ouvrir le dossier lie",id="case"} end
    if allowed("enforcementProgress") then actions[#actions+1]={text="Ajouter un compte rendu d'execution",id="progress"} end
    if allowed("enforcementWrite") then actions[#actions+1]={text="Changer le statut d'execution",id="status"} end

    local a=menu(e.id.." - "..e.targetName,actions,
      "["..e.status.."] "..enforcementTypeLabel(e.enforcementType).." / "..(e.visibility or "restricted"))
    if not a then return end

    if a.id=="read" then
      textPage(e.id,enforcementSections(e))

    elseif a.id=="print" then
      local ok,r=printer.enforcement(e)
      message("IMPRESSION",ok and ("Mesure imprimee: "..r.." page(s).") or r,ok and palette.ok or palette.bad)

    elseif a.id=="case" then
      caseDetails(e.caseId)

    elseif a.id=="progress" then
      local reference=prompt("Reference / preuve associee (optionnel)")
      local note=multi("COMPTE RENDU D'EXECUTION","")
      local r,er=rpc("ENFORCEMENT_ADD_PROGRESS",{id=e.id,reference=reference,note=note})
      message("EXECUTION",r and "Compte rendu ajoute et scelle." or er,r and palette.ok or palette.bad)

    elseif a.id=="status" then
      local st=menu("STATUT D'EXECUTION",{
        {text="Ordonnee",v="ordered"},
        {text="Active / en cours",v="active"},
        {text="Partiellement executee",v="partial"},
        {text="Executee / respectee",v="complied"},
        {text="Violation / non-respect",v="breached"},
        {text="Levee",v="lifted"},
        {text="Expiree",v="expired"}
      },"Actuel: "..e.status)
      if st then
        local reason=prompt("Motif / observation")
        local r,er=rpc("ENFORCEMENT_UPDATE",{id=e.id,status=st.v,reason=reason})
        message("EXECUTION",r and ("Statut: "..r.status) or er,r and palette.ok or palette.bad)
      end
    end
  end
end

enforcementsScreen=function(query,status,stateId,caseId)
  query=query or ""
  status=status or ""
  stateId=stateId or ""
  caseId=caseId or ""

  while true do
    local rows,err=rpc("ENFORCEMENT_LIST",{query=query,status=status,stateId=stateId,caseId=caseId})
    if not rows then message("EXECUTION",err,palette.bad);return end

    local items={}
    if allowed("enforcementWrite") then items[#items+1]={text="[+] Creer une mesure d'execution",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer par statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser recherche/statut",id="reset"} end

    for _,e in ipairs(rows) do
      items[#items+1]={
        text=e.id.."  "..e.targetName.."  "..enforcementTypeLabel(e.enforcementType).."  ["..e.status.."]",
        enforcement=e
      }
    end

    local scope=""
    if stateId~="" then scope=scope.." / Etat "..stateId end
    if caseId~="" then scope=scope.." / Dossier "..caseId end
    local p=menu("EXECUTION / SANCTIONS",items,#rows.." mesure(s)"..scope)
    if not p then return end

    if p.id=="new" then
      createEnforcement(caseId~="" and caseId or nil,nil)

    elseif p.id=="search" then
      query=prompt("Recherche execution",query)

    elseif p.id=="status" then
      local st=menu("FILTRER LES MESURES",{
        {text="Toutes",v=""},{text="Ordonnees",v="ordered"},{text="Actives",v="active"},
        {text="Partielles",v="partial"},{text="Executees",v="complied"},
        {text="En violation",v="breached"},{text="Levees",v="lifted"},{text="Expirees",v="expired"}
      })
      if st then status=st.v end

    elseif p.id=="reset" then
      query="";status=""

    elseif p.enforcement then
      enforcementDetails(p.enforcement.id)
    end
  end
end

local function notificationCenter()
  while true do
    local rows,err=rpc("NOTICE_LIST",{})
    if not rows then message("NOTIFICATIONS",err,palette.bad);return end

    local unread=0
    local items={
      {text="[OK] Marquer toutes comme lues",id="all"}
    }
    for _,n in ipairs(rows) do
      if not n.read then unread=unread+1 end
      local sev=string.upper(n.severity or "info")
      items[#items+1]={
        text=(n.read and "    " or "[!] ").."["..sev.."] "..n.title,
        notice=n
      }
    end

    local p=menu("CENTRE DE NOTIFICATIONS",items,unread.." non lue(s) / "..#rows.." visible(s)")
    if not p then return end

    if p.id=="all" then
      local r,e=rpc("NOTICE_MARK_ALL",{})
      message("NOTIFICATIONS",r and (tostring(r.count).." notification(s) marquee(s) comme lues.") or e,r and palette.ok or palette.bad)

    elseif p.notice then
      local n=p.notice
      if not n.read then rpc("NOTICE_MARK_READ",{id=n.id}) end
      local actions={
        {text="Lire le message",id="read"}
      }
      if n.objectType and n.objectId then actions[#actions+1]={text="Ouvrir l'element associe",id="open"} end
      local a=menu(n.title,actions,(n.createdAt or "").." / "..string.upper(n.severity or "info"))
      if a and a.id=="read" then
        textPage(n.id,{
          {label=n.title,text=n.body or ""},
          {label="Importance",text=n.severity or "info"},
          {label="Date",text=n.createdAt or ""},
          {label="Element associe",text=(n.objectType or "-").." / "..(n.objectId or "-")}
        })
      elseif a and a.id=="open" then
        if n.objectType=="bill" then billDetails(n.objectId)
        elseif n.objectType=="resolution" then resolutionDetails(n.objectId)
        elseif n.objectType=="treaty" then treatyDetails(n.objectId)
        elseif n.objectType=="case" then caseDetails(n.objectId)
        elseif n.objectType=="enforcement" then enforcementDetails(n.objectId)
        else message("NOTIFICATION","Type d'element non navigable: "..tostring(n.objectType),palette.warn) end
      end
    end
  end
end

local function sessionTypeLabel(v)
  local labels={
    assembly="Assemblee des Etats",security_council="Conseil de paix et de securite",
    diplomatic="Session diplomatique",emergency="Session extraordinaire / urgence",
    committee="Commission / comite",other="Autre session"
  }
  return labels[v] or tostring(v or "")
end

local function chooseSessionType(current)
  local p=menu("TYPE DE SESSION",{
    {text="Assemblee des Etats",v="assembly"},
    {text="Conseil de paix et de securite",v="security_council"},
    {text="Session diplomatique",v="diplomatic"},
    {text="Session extraordinaire / urgence",v="emergency"},
    {text="Commission / comite",v="committee"},
    {text="Autre",v="other"}
  },"Actuel: "..sessionTypeLabel(current))
  return p and p.v or current or "assembly"
end

local function chooseAgendaObject(kind)
  if kind=="law" then
    local law=referenceBrowser({mode="browse",pick=true,readonly=true})
    return law and law.ref or nil, law and law.title or nil
  end

  local action=nil
  local title=""
  if kind=="bill" then action="BILL_LIST";title="PROPOSITIONS"
  elseif kind=="resolution" then action="RESOLUTION_LIST";title="RESOLUTIONS"
  elseif kind=="treaty" then action="TREATY_LIST";title="TRAITES"
  elseif kind=="case" then action="CASE_LIST";title="DOSSIERS"
  elseif kind=="enforcement" then action="ENFORCEMENT_LIST";title="EXECUTION"
  else return nil,nil end

  local rows,err=rpc(action,{})
  if not rows then message("ORDRE DU JOUR",err,palette.bad);return nil,nil end
  local items={}
  for _,row in ipairs(rows) do
    local ref=row.id or row.ref
    local name=row.title or row.summary or row.targetName or ref
    items[#items+1]={text=tostring(ref).."  "..tostring(name),row=row}
  end
  if #items==0 then message("ORDRE DU JOUR","Aucun element disponible.",palette.warn);return nil,nil end
  local p=menu(title,items,"Selectionnez l'element a inscrire.")
  if not p then return nil,nil end
  local row=p.row
  return row.id or row.ref, row.title or row.summary or row.targetName or row.id or row.ref
end

local function openAgendaObject(item)
  if not item then return end
  if item.kind=="law" then viewLaw(item.ref)
  elseif item.kind=="bill" then billDetails(item.ref)
  elseif item.kind=="resolution" then resolutionDetails(item.ref)
  elseif item.kind=="treaty" then treatyDetails(item.ref)
  elseif item.kind=="case" then caseDetails(item.ref)
  elseif item.kind=="enforcement" then enforcementDetails(item.ref)
  else
    textPage(item.id or "AGENDA",{
      {label=item.title or "Element",text=item.description or ""},
      {label="Statut",text=item.status or ""},
      {label="Notes",text=item.notes or ""},
      {label="Issue",text=item.outcome or ""}
    })
  end
end

local function attendanceText(sess)
  local rows={}
  for stateId,row in pairs(sess.attendance or {}) do
    rows[#rows+1]=(row.stateName or stateId).." / "..(row.checkedInAt or "").." / "..(row.by or "")
  end
  table.sort(rows)
  return #rows>0 and table.concat(rows,"\n") or "Aucune presence enregistree."
end

local function agendaText(sess)
  local rows={}
  for _,item in ipairs(sess.agenda or {}) do
    rows[#rows+1]=(item.id or "?").." ["..(item.status or "?").."] "..(item.title or "")..
      ((item.ref and item.ref~="") and (" / "..item.ref) or "")..
      ((item.outcome and item.outcome~="") and ("\nIssue: "..item.outcome) or "")
  end
  return #rows>0 and table.concat(rows,"\n\n") or "Ordre du jour vide."
end

local function sessionAgendaScreen(sess)
  while true do
    local items={}
    if allowed("sessionWrite") and sess.status~="closed" and sess.status~="cancelled" then
      items[#items+1]={text="[+] Ajouter un element",id="new"}
    end
    for _,item in ipairs(sess.agenda or {}) do
      items[#items+1]={
        text=(item.id or "?").."  ["..(item.status or "?").."] "..(item.title or "")..
          ((item.ref and item.ref~="") and (" / "..item.ref) or ""),
        item=item
      }
    end

    local p=menu("ORDRE DU JOUR "..sess.id,items,#(sess.agenda or {}).." element(s)")
    if not p then return sess end

    if p.id=="new" then
      local kindMenu=menu("TYPE D'ELEMENT",{
        {text="Proposition de loi / BILL",v="bill"},
        {text="Resolution / RES",v="resolution"},
        {text="Traite / TREATY",v="treaty"},
        {text="Dossier judiciaire / CASE",v="case"},
        {text="Article du Code",v="law"},
        {text="Mesure d'execution / ENF",v="enforcement"},
        {text="Point libre",v="custom"}
      })
      if kindMenu then
        local ref,title="",""
        if kindMenu.v=="custom" then
          title=prompt("Titre du point")
        else
          ref,title=chooseAgendaObject(kindMenu.v)
        end
        if title and title~="" then
          local description=prompt("Description courte (optionnel)")
          local out,e=rpc("SESSION_ADD_AGENDA",{
            id=sess.id,kind=kindMenu.v,ref=ref or "",title=title,description=description
          })
          message("ORDRE DU JOUR",out and "Element ajoute." or e,out and palette.ok or palette.bad)
          if out then sess=out end
        end
      end

    elseif p.item then
      local item=p.item
      local actions={{text="Ouvrir / consulter l'element",id="open"}}
      if allowed("sessionWrite") and sess.status=="open" then
        actions[#actions+1]={text="Mettre a jour le statut / issue",id="status"}
      end
      if allowed("sessionWrite") and sess.status=="scheduled" then
        actions[#actions+1]={text="Retirer de l'ordre du jour",id="remove"}
      end
      local a=menu(item.id.." - "..item.title,actions,
        (item.kind or "").." / "..(item.ref or "").." / "..(item.status or ""))
      if a and a.id=="open" then
        openAgendaObject(item)
      elseif a and a.id=="remove" then
        local out,e=rpc("SESSION_REMOVE_AGENDA",{id=sess.id,itemId=item.id})
        message("ORDRE DU JOUR",out and "Element retire." or e,out and palette.ok or palette.bad)
        if out then sess=out end
      elseif a and a.id=="status" then
        local st=menu("STATUT DU POINT",{
          {text="En attente",v="pending"},
          {text="En discussion",v="discussing"},
          {text="Discute",v="discussed"},
          {text="Vote / traite",v="voted"},
          {text="Reporte",v="postponed"},
          {text="Retire",v="withdrawn"}
        },"Actuel: "..(item.status or "pending"))
        if st then
          local notes=multi("NOTES SUR LE POINT",item.notes or "")
          local outcome=multi("ISSUE / DECISION / SUITE",item.outcome or "")
          local out,e=rpc("SESSION_SET_ITEM_STATUS",{
            id=sess.id,itemId=item.id,status=st.v,notes=notes,outcome=outcome
          })
          message("ORDRE DU JOUR",out and ("Point: "..st.v) or e,out and palette.ok or palette.bad)
          if out then sess=out end
        end
      end
    end
  end
end

local function sessionDetails(id)
  while true do
    local sess,err=rpc("SESSION_GET",{id=id})
    if not sess then message("SESSION",err,palette.bad);return end
    sess.agenda=sess.agenda or {}
    sess.attendance=sess.attendance or {}

    local actions={
      {text="Lire la fiche / ordre du jour",id="read"},
      {text="Ordre du jour ("..#sess.agenda..")",id="agenda"},
      {text="Presences des Etats",id="attendance"},
      {text="Imprimer la session / proces-verbal",id="print"}
    }

    if allowed("sessionAttend") and sess.status=="open" then
      actions[#actions+1]={text="Enregistrer la presence de mon Etat",id="checkin"}
    end

    if allowed("sessionWrite") and sess.status=="scheduled" then
      actions[#actions+1]={text="Modifier la convocation",id="edit"}
      actions[#actions+1]={text="Ouvrir officiellement la session",id="open"}
      actions[#actions+1]={text="Annuler la session",id="cancel"}
    elseif allowed("sessionWrite") and sess.status=="open" then
      actions[#actions+1]={text="Clore et rediger le proces-verbal final",id="close"}
      actions[#actions+1]={text="Annuler exceptionnellement la session",id="cancel"}
    end

    local present=0
    for _ in pairs(sess.attendance) do present=present+1 end
    local a=menu(sess.id.." - "..sess.title,actions,
      "["..sess.status.."] "..sessionTypeLabel(sess.sessionType).." | "..present.." Etat(s) present(s)")
    if not a then return end

    if a.id=="read" then
      textPage(sess.id,{
        {label="Session",text=sess.title or ""},
        {label="Type / statut",text=sessionTypeLabel(sess.sessionType).." / "..(sess.status or "")},
        {label="Date / lieu",text=(sess.scheduledFor or "-").." / "..(sess.location or "-")},
        {label="Description",text=sess.description or ""},
        {label="Ordre du jour",text=agendaText(sess)},
        {label="Presences",text=attendanceText(sess)},
        {label="Proces-verbal final",text=sess.minutes or "-"},
        {label="Conclusions",text=sess.outcome or "-"},
        {label="Sceau convocation",text=sess.noticeSeal or "-"},
        {label="Sceau ouverture",text=sess.openSeal or "-"},
        {label="Sceau du PV",text=sess.closeSeal or "-"},
        {label="Annulation",text=(sess.cancelReason or "-")..(sess.cancelSeal and (" / "..sess.cancelSeal) or "")}
      })

    elseif a.id=="agenda" then
      sessionAgendaScreen(sess)

    elseif a.id=="attendance" then
      textPage("PRESENCES "..sess.id,{{label="Etats enregistres",text=attendanceText(sess)}})

    elseif a.id=="print" then
      local ok,pages=printer.session(sess)
      message("IMPRESSION",ok and ("Session imprimee: "..pages.." page(s).") or pages,ok and palette.ok or palette.bad)

    elseif a.id=="checkin" then
      local out,e=rpc("SESSION_CHECKIN",{id=sess.id})
      message("PRESENCE",out and "Presence de votre Etat enregistree." or e,out and palette.ok or palette.bad)

    elseif a.id=="edit" then
      local title=prompt("Titre",sess.title)
      local typ=chooseSessionType(sess.sessionType)
      local scheduledFor=prompt("Date / heure",sess.scheduledFor or "")
      local location=prompt("Lieu / salle",sess.location or "")
      local description=multi("DESCRIPTION / OBJET",sess.description or "")
      local out,e=rpc("SESSION_EDIT",{
        id=sess.id,title=title,sessionType=typ,scheduledFor=scheduledFor,
        location=location,description=description
      })
      message("SESSION",out and "Convocation mise a jour." or e,out and palette.ok or palette.bad)

    elseif a.id=="open" then
      local confirm=menu("OUVRIR LA SESSION",{
        {text="Ouvrir officiellement maintenant",id="yes"},
        {text="Annuler",id="no"}
      },"L'ordre du jour courant sera inclus dans le sceau d'ouverture.")
      if confirm and confirm.id=="yes" then
        local out,e=rpc("SESSION_OPEN",{id=sess.id})
        message("SESSION",out and ("Session ouverte / sceau "..tostring(out.openSeal)) or e,out and palette.ok or palette.bad)
      end

    elseif a.id=="close" then
      local minutes=multi("PROCES-VERBAL FINAL DE LA SESSION",sess.minutes or "")
      local outcome=multi("CONCLUSIONS / DECISIONS / SUITES",sess.outcome or "")
      local out,e=rpc("SESSION_CLOSE",{id=sess.id,minutes=minutes,outcome=outcome})
      message("SESSION",out and ("Session cloturee / sceau "..tostring(out.closeSeal)) or e,out and palette.ok or palette.bad)

    elseif a.id=="cancel" then
      local reason=multi("MOTIF D'ANNULATION","")
      local out,e=rpc("SESSION_CANCEL",{id=sess.id,reason=reason})
      message("SESSION",out and "Annulation enregistree et scellee." or e,out and palette.ok or palette.bad)
    end
  end
end

local function sessionsScreen(query,status)
  query=query or ""
  status=status or ""

  while true do
    local rows,err=rpc("SESSION_LIST",{query=query,status=status})
    if not rows then message("SESSIONS",err,palette.bad);return end

    local items={}
    if allowed("sessionWrite") then items[#items+1]={text="[+] Convoquer une session",id="new"} end
    items[#items+1]={text="[?] Rechercher",id="search"}
    items[#items+1]={text="[S] Filtrer par statut"..(status~="" and (" ["..status.."]") or ""),id="status"}
    if query~="" or status~="" then items[#items+1]={text="[R] Reinitialiser les filtres",id="reset"} end

    for _,sess in ipairs(rows) do
      items[#items+1]={
        text=sess.id.."  "..(sess.scheduledFor or "-").."  "..sess.title.."  ["..sess.status.."]",
        session=sess
      }
    end

    local p=menu("CALENDRIER / SESSIONS",items,#rows.." session(s)")
    if not p then return end

    if p.id=="new" then
      local title=prompt("Titre de la session")
      local typ=chooseSessionType("assembly")
      local scheduledFor=prompt("Date / heure")
      local location=prompt("Lieu / salle")
      local description=multi("DESCRIPTION / OBJET","")
      local out,e=rpc("SESSION_CREATE",{
        title=title,sessionType=typ,scheduledFor=scheduledFor,location=location,description=description
      })
      message("SESSION",out and ("Convoquee: "..out.id) or e,out and palette.ok or palette.bad)

    elseif p.id=="search" then
      query=prompt("Recherche session",query)

    elseif p.id=="status" then
      local st=menu("STATUT SESSION",{
        {text="Toutes",v=""},{text="Programmees",v="scheduled"},{text="Ouvertes",v="open"},
        {text="Cloturees",v="closed"},{text="Annulees",v="cancelled"}
      })
      if st then status=st.v end

    elseif p.id=="reset" then
      query="";status=""

    elseif p.session then
      sessionDetails(p.session.id)
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

local function verifySealScreen(seal)
  seal=common.trim(seal or "")
  if seal=="" then seal=prompt("Sceau officiel a verifier") end
  if seal=="" then return end

  local r,e=rpc("VERIFY_SEAL",{seal=seal})
  if not r then
    message("VERIFICATION",e,palette.bad)
    return
  end
  if not r.valid then
    message("SCEAU INCONNU","Le serveur ne reconnait pas ce sceau: "..seal,palette.bad)
    return
  end

  textPage("SCEAU VALIDE",{
    {label="Verification",text="VALIDE / PRESENT DANS LE REGISTRE CENTRAL"},
    {label="Sceau",text=r.seal or seal},
    {label="Type",text=r.kind or ""},
    {label="Document parent",text=r.parentId or ""},
    {label="Reference",text=r.reference or ""},
    {label="Titre",text=r.title or ""},
    {label="Statut",text=r.status or ""},
    {label="Emis le",text=r.issuedAt or ""},
    {label="Emis par",text=r.issuedBy or ""},
    {label="Etat signataire",text=r.stateName or ""},
    {label="Confidentialite",text=r.confidential and "Le sceau est authentique, mais le contenu du document est protege." or "Metadonnees accessibles."}
  })
end

local function helpScreen()
  textPage("AIDE / RACCOURCIS",{
    {label="Navigation du Code",text="Parcourez par Livre, utilisez la recherche plein texte ou filtrez par statut. Un article peut etre ouvert, imprime et son historique de versions consulte."},
    {label="Editeur juridique",text="F2: Livres / categories\nF3: Recherche d'article\nF4: Inserer une citation a la position du curseur\nF6: Panier juridique multi-selection\nF7: Recuperer un brouillon autosauvegarde\nF5: Terminer la redaction\nEchap: menu de sortie"},
    {label="Assemblee",text="Les propositions BILL peuvent creer un article ou amender un texte existant. Les terminaux delegate rattaches a un Etat votent POUR, CONTRE ou ABSTENTION. Apres cloture, une proposition adoptee peut etre promulguee dans le Code."},
    {label="Resolutions",text="Les resolutions RES servent aux decisions institutionnelles qui ne modifient pas directement le Code: securite, sanctions, humanitaire, urgence, adhesion, cessez-le-feu ou mission d'observation. Elles disposent du meme quorum et vote par Etat, puis peuvent creer automatiquement une mesure ENF."},
    {label="Etats membres",text="Le registre STATE conserve le statut, le gouvernement et le representant des pays. Un administrateur peut rattacher un terminal delegate a un Etat pour ses votes officiels."},
    {label="Traites",text="Les traites TREATY sont rediges puis figes avant signature. Chaque Etat partie signe depuis un terminal delegate rattache. Une fois toutes les signatures reunies, le traite peut entrer en vigueur avec un sceau officiel."},
    {label="Notifications",text="Le serveur cree des alertes pour les votes ouverts, signatures de traites, audiences, appels et mesures d'execution. Les delegues recoivent automatiquement les actions qui concernent leur Etat."},
    {label="Execution",text="Le registre ENF suit amendes, restitutions, embargos, gels d'avoirs, restrictions, inspections et autres mesures issues des decisions. Chaque changement et compte rendu peut etre scelle et imprime."},
    {label="Dossiers",text="Le panier juridique permet d'ajouter ou retirer plusieurs articles d'un dossier. Chaque fait, preuve, audience, ordonnance, changement de statut et jugement alimente la chronologie."},
    {label="Jugements",text="Lors de l'enregistrement, le systeme fige la reference, le titre et la version des articles cites. Les jugements, ordonnances, audiences, appels et scrutins recoivent aussi un sceau d'integrite applicatif."},
    {label="Appels",text="Le greffe ou le juge peut deposer un appel. Un juge peut ensuite confirmer, modifier, annuler, rejeter la decision ou renvoyer l'affaire a une nouvelle audience."},
    {label="Affichage public",text="ic public lance un registre tournant sur Monitor. ic display CASE-... affiche un dossier public specifique au tribunal."},
    {label="Verification des documents",text="Chaque sceau imprime peut etre controle contre le serveur central depuis le menu ou avec ic verify <SCEAU>. Un document scelle peut etre confirme authentique sans reveler son contenu."},
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
      ("Role "..cfg.role.." | "..dash.laws.." art. | "..tostring((dash.votingBills or 0)+(dash.votingResolutions or 0)).." scrutin(s) | "..tostring(dash.activeTreaties or 0).." traites | "..tostring(dash.activeEnforcements or 0).." exec. | "..tostring(dash.unreadNotices or 0).." notif. | r"..dash.revision)
      or ("HORS LIGNE - "..tostring(err))

    local items={
      {text=(dash and (dash.unreadNotices or 0)>0) and ("[!] NOTIFICATIONS ("..dash.unreadNotices..")") or "CENTRE DE NOTIFICATIONS",id="notices"},
      {text="CODE INTERNATIONAL / ARTICLES",id="laws"},
      {text="ASSEMBLEE / PROPOSITIONS / VOTES",id="bills"},
      {text="RESOLUTIONS / CONSEIL / SECURITE",id="resolutions"},
      {text="TRAITES / DIPLOMATIE",id="treaties"},
      {text="REGISTRE DES ETATS MEMBRES",id="states"},
      {text="DOSSIERS JUDICIAIRES",id="cases"},
      {text="EXECUTION / SANCTIONS / REPARATIONS",id="enforcement"},
      {text="RECHERCHE GLOBALE",id="search"},
      {text="VERIFIER UN SCEAU OFFICIEL",id="verify"}
    }
    if allowed("audit") then
      items[#items+1]={text="JOURNAL D'AUDIT",id="audit"}
    end
    items[#items+1]={text="AIDE / RACCOURCIS",id="help"}
    items[#items+1]={text="RESEAU / IMPRIMANTE / DIAGNOSTIC",id="network"}
    items[#items+1]={text="QUITTER",id="quit"}

    local p=menu("BUREAU JURIDIQUE",items,subtitle)
    if not p or p.id=="quit" then clear();return end

    if p.id=="notices" then
      notificationCenter()
    elseif p.id=="laws" then
      lawsScreen("")
    elseif p.id=="bills" then
      billsScreen("","")
    elseif p.id=="resolutions" then
      resolutionsScreen("","")
    elseif p.id=="treaties" then
      treatiesScreen("","","")
    elseif p.id=="states" then
      statesScreen("","")
    elseif p.id=="cases" then
      casesScreen("")
    elseif p.id=="enforcement" then
      enforcementsScreen("","","","")
    elseif p.id=="verify" then
      verifySealScreen("")
    elseif p.id=="search" then
      local q=prompt("Recherche (article, titre, partie)")
      local kind=menu("RECHERCHE",{
        {text="Dans les articles",id="law"},
        {text="Dans les propositions / votes",id="bill"},
        {text="Dans les resolutions",id="resolution"},
        {text="Dans les traites",id="treaty"},
        {text="Dans les Etats membres",id="state"},
        {text="Dans les dossiers",id="case"},
        {text="Dans les mesures d'execution",id="enforcement"}
      })
      if kind and kind.id=="law" then lawsScreen(q)
      elseif kind and kind.id=="bill" then billsScreen(q,"")
      elseif kind and kind.id=="resolution" then resolutionsScreen(q,"")
      elseif kind and kind.id=="treaty" then treatiesScreen(q,"","")
      elseif kind and kind.id=="state" then statesScreen(q,"")
      elseif kind and kind.id=="enforcement" then enforcementsScreen(q,"","","")
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

function C.verify(seal)
  cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client appaire requis.",0) end
  common.openModems()
  verifySealScreen(seal)
end

function C.notifications()
  cfg=common.loadConfig()
  if not cfg or cfg.role=="server" then error("Terminal client appaire requis.",0) end
  common.openModems()
  notificationCenter()
end

function C.doctor()
  cfg=common.loadConfig()
  common.openModems()
  clear()
  bar("DIAGNOSTIC v"..common.VERSION)
  local y=4

  local function check(label,ok,detail)
    at(2,y,label..": "..(ok and "OK" or "ERREUR")..(detail and (" - "..detail) or ""),ok and palette.ok or palette.bad)
    y=y+1
  end

  check("Configuration",cfg~=nil,cfg and (cfg.role or "?") or "absente")

  local required={
    "/ic.lua",
    "/international_code/common.lua",
    "/international_code/server.lua",
    "/international_code/client.lua",
    "/international_code/printer.lua",
    "/international_code/public.lua"
  }
  local missing={}
  for _,path in ipairs(required) do if not fs.exists(path) then missing[#missing+1]=path end end
  check("Fichiers programme",#missing==0,#missing==0 and (#required.." presents") or table.concat(missing,", "))

  local seedCount=0
  local seedOk=true
  for i=1,5 do
    local path=string.format("/international_code/seed/%03d.lua",i)
    if not fs.exists(path) then
      seedOk=false
    else
      local ok,t=pcall(dofile,path)
      if not ok or type(t)~="table" then seedOk=false else seedCount=seedCount+#t end
    end
  end
  check("Corpus juridique",seedOk and seedCount==500,tostring(seedCount).."/500 articles")

  local modems=common.openModems()
  check("Modem",modems>0,tostring(modems).." detecte(s)")

  local pa,pn=printer.available()
  at(2,y,"Imprimante: "..(pa and ("OK - "..pn) or "optionnelle / absente"),pa and palette.ok or palette.warn)
  y=y+1

  if cfg and cfg.role~="server" then
    local d,e=rpc("SERVER_INFO",{},3)
    check("Serveur",d~=nil,d and ("#"..tostring(cfg.serverId)) or tostring(e))
    if d then
      local sv=tostring(d.meta and d.meta.version or "?")
      check("Versions",sv==common.VERSION,"client "..common.VERSION.." / serveur "..sv)
    end
  elseif cfg and cfg.role=="server" then
    check("Etat serveur local",fs.exists(common.STATE),fs.exists(common.STATE) and "base presente" or "base absente")
  end

  footer("ic update si une version ou un fichier est incorrect")
  os.pullEvent("key")
end

return C
