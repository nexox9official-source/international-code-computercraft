local common=dofile("/international_code/common.lua")
local P={}

local function getPrinter()
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name)=="printer" then return peripheral.wrap(name),name end
  end
  return nil,nil
end

function P.available()
  local p,name=getPrinter()
  return p~=nil,name
end

local function append(lines,label,text,width)
  if label and label~="" then lines[#lines+1]=label end
  for _,line in ipairs(common.wrap(tostring(text or ""),width or 25)) do lines[#lines+1]=line end
  lines[#lines+1]=""
end

local function printLines(title,lines)
  local printer=getPrinter()
  if not printer then return false,"Aucune imprimante connectee." end
  local width,height=25,21
  if printer.getPageSize then
    local ok,w,h=pcall(printer.getPageSize)
    if ok and w and h then width,height=w,h end
  end
  local bodyHeight=math.max(5,height-3)
  local pages=math.max(1,math.ceil(#lines/bodyHeight))
  local cursor=1
  for page=1,pages do
    if not printer.newPage() then return false,"Papier ou encre insuffisants." end
    if printer.setPageTitle then pcall(printer.setPageTitle,common.fit(title,32)) end
    printer.setCursorPos(1,1)
    printer.write(common.fit("NORTH COALITION / REGISTRE",width))
    local y=2
    while y<=bodyHeight+1 and cursor<=#lines do
      printer.setCursorPos(1,y)
      printer.write(common.fit(lines[cursor],width))
      cursor=cursor+1;y=y+1
    end
    printer.setCursorPos(1,height)
    printer.write(common.fit("Page "..page.."/"..pages,width))
    if not printer.endPage() then return false,"Impossible de finaliser la page." end
  end
  return true,pages
end

function P.law(law)
  local lines={}
  append(lines,law.display_reference or law.id,(law.title or "").." / "..(law.id or ""),25)
  append(lines,"BRANCHE",law.legal_branch or "-",25)
  append(lines,"CATEGORIE",(law.category_code or "-").." / "..(law.category_name or ""),25)
  append(lines,"LIVRE",law.book_title or "-",25)
  append(lines,"TITRE",(law.title_code or "-").." / "..(law.title_group or ""),25)
  append(lines,"CHAPITRE",(law.chapter_code or "-").." / "..(law.chapter or ""),25)
  append(lines,"NATURE",law.article_kind or "-",25)
  append(lines,"STATUT / VERSION",(law.status or "?").." / v"..tostring(law.version or "?"),25)
  if law.severity then append(lines,"CLASSE PENALE",law.severity,25) end
  append(lines,"AUTORITE",law.responsible_authority or "-",25)
  append(lines,"MINISTERE",law.responsible_ministry or "-",25)
  append(lines,"TEXTE",law.text or "",25)
  if law.effective_at then append(lines,"ENTREE EN VIGUEUR",law.effective_at,25) end
  return printLines(law.display_reference or law.id or "NC-ARTICLE",lines)
end

function P.ministry(m)
  local lines={}
  append(lines,"MINISTERE",m.code.." / "..(m.name or ""),25)
  append(lines,"COMPETENCES",table.concat(m.scope or {},", "),25)
  append(lines,"TITULAIRE",m.holderIdentity or "VACANT",25)
  append(lines,"MODE DE NOMINATION",m.appointmentMode or "-",25)
  append(lines,"DATE",m.appointedAt or m.vacantSince or "-",25)
  append(lines,"SCEAU",m.appointmentSeal or "-",25)
  if m.history and #m.history>0 then
    lines[#lines+1]="HISTORIQUE"
    for _,h in ipairs(m.history) do
      for _,line in ipairs(common.wrap((h.at or "").." / "..(h.event or "?").." / "..(h.identity or "").." / "..(h.mode or h.reason or ""),25)) do
        lines[#lines+1]=line
      end
      if h.seal then for _,line in ipairs(common.wrap("Sceau: "..h.seal,25)) do lines[#lines+1]=line end end
      lines[#lines+1]=""
    end
  end
  return printLines(m.code or "MINISTERE",lines)
end

function P.bill(b)
  local lines={}
  append(lines,"PROJET DE LOI",b.id.." / "..(b.title or ""),25)
  append(lines,"TYPE",b.proposalType or "-",25)
  append(lines,"STATUT",b.stage or "-",25)
  append(lines,"RESUME",b.summary or "",25)
  append(lines,"CORPS ELECTORAL",b.electorate or "-",25)
  append(lines,"REGLE DE MAJORITE",b.threshold or "-",25)
  if b.targetRef and b.targetRef~="" then append(lines,"ARTICLE CIBLE",b.targetRef,25) end
  if b.targetRefs and #b.targetRefs>0 then append(lines,"ARTICLES CIBLES",table.concat(b.targetRefs,", "),25) end
  if b.categoryCode and b.categoryCode~="" then append(lines,"CATEGORIE",b.categoryCode,25) end
  if b.proposedTitle and b.proposedTitle~="" then append(lines,"TITRE PROPOSE",b.proposedTitle,25) end
  if b.proposedText and b.proposedText~="" then append(lines,"TEXTE PROPOSE",b.proposedText,25) end
  if b.tally then
    append(lines,"SCRUTIN","Pour "..tostring(b.tally.yes or 0).." / Contre "..tostring(b.tally.no or 0)..
      " / Abstention "..tostring(b.tally.abstain or 0).." / Participation "..tostring(b.tally.participation or 0).."/"..tostring(b.tally.eligible or 0),25)
  end
  append(lines,"RESULTAT",b.result or "-",25)
  append(lines,"SCEAU RESULTAT",b.resultSeal or "-",25)
  append(lines,"SCEAU PROMULGATION",b.enactmentSeal or "-",25)
  return printLines(b.id or "NC-BILL",lines)
end

function P.election(e)
  local lines={}
  append(lines,"SCRUTIN MINISTERIEL",e.id.." / "..(e.title or ""),25)
  append(lines,"MINISTERE",e.ministryCode or "-",25)
  append(lines,"ELECTORAT",e.electorate or "-",25)
  append(lines,"STATUT",e.stage or "-",25)
  local candidates={}
  for _,c in ipairs(e.candidates or {}) do candidates[#candidates+1]=(c.identity or c.clientId).." / "..(c.clientId or "") end
  append(lines,"CANDIDATS",table.concat(candidates,"\n"),25)
  if e.tally then
    local counts={}
    for clientId,n in pairs(e.tally.counts or {}) do counts[#counts+1]=clientId.." = "..n end
    table.sort(counts)
    append(lines,"RESULTATS",table.concat(counts,"\n").."\nAbstention: "..tostring(e.tally.abstain or 0)..
      "\nParticipation: "..tostring(e.tally.participation or 0).."/"..tostring(e.tally.eligible or 0),25)
  end
  append(lines,"ELU",e.winnerIdentity or "-",25)
  append(lines,"SCEAU OUVERTURE",e.openSeal or "-",25)
  append(lines,"SCEAU RESULTAT",e.resultSeal or "-",25)
  append(lines,"SCEAU NOMINATION",e.appointmentSeal or "-",25)
  return printLines(e.id or "NC-ELECT",lines)
end

function P.decree(d)
  local lines={}
  append(lines,"DECRET",d.id.." / "..(d.title or ""),25)
  append(lines,"PORTEE",d.scope or "-",25)
  append(lines,"MINISTERE",d.ministryCode or "-",25)
  append(lines,"BASE LEGALE",d.legalBasis or "-",25)
  append(lines,"STATUT",d.status or "-",25)
  append(lines,"TEXTE",d.body or "",25)
  append(lines,"AUTEUR",d.createdBy or "-",25)
  append(lines,"PUBLICATION",(d.publishedAt or "-").." / "..(d.publishedBy or "-"),25)
  append(lines,"SCEAU",d.seal or "-",25)
  if d.repealReason then append(lines,"ABROGATION",d.repealReason.." / "..(d.repealSeal or "-"),25) end
  return printLines(d.id or "NC-DEC",lines)
end


function P.caseFile(case)
  if not case then return false,"Dossier introuvable." end
  local lines={}
  append(lines,"DOSSIER NATIONAL",case.id.." / "..(case.title or ""),25)
  append(lines,"TYPE / STATUT",(case.caseType or "-").." / "..(case.status or "-"),25)
  append(lines,"VISIBILITE",case.visibility or "-",25)
  append(lines,"DEMANDEUR",case.complainant or "-",25)
  append(lines,"MIS EN CAUSE",case.accused or "-",25)
  append(lines,"RESUME",case.summary or "",25)
  append(lines,"SCEAU INITIAL",case.seal or "-",25)

  if #(case.facts or {})>0 then
    lines[#lines+1]="FAITS"
    for _,row in ipairs(case.facts or {}) do
      for _,l in ipairs(common.wrap((row.id or "?").." / "..(row.text or ""),25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap("Sceau: "..(row.seal or "-"),25)) do lines[#lines+1]=l end
      lines[#lines+1]=""
    end
  end

  if #(case.evidence or {})>0 then
    lines[#lines+1]="PREUVES"
    for _,row in ipairs(case.evidence or {}) do
      for _,l in ipairs(common.wrap((row.id or "?").." / "..(row.label or ""),25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap(row.description or "",25)) do lines[#lines+1]=l end
      if row.source and row.source~="" then for _,l in ipairs(common.wrap("Source: "..row.source,25)) do lines[#lines+1]=l end end
      for _,l in ipairs(common.wrap("Sceau: "..(row.seal or "-"),25)) do lines[#lines+1]=l end
      lines[#lines+1]=""
    end
  end

  append(lines,"ARTICLES CITES",table.concat(case.citedArticles or {},", "),25)

  if #(case.hearings or {})>0 then
    lines[#lines+1]="AUDIENCES"
    for _,h in ipairs(case.hearings or {}) do
      for _,l in ipairs(common.wrap((h.id or "?").." ["..(h.status or "?").."] "..(h.scheduledFor or ""),25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap(h.subject or "",25)) do lines[#lines+1]=l end
      if h.recordSeal then for _,l in ipairs(common.wrap("PV: "..h.recordSeal,25)) do lines[#lines+1]=l end end
      lines[#lines+1]=""
    end
  end

  if #(case.orders or {})>0 then
    lines[#lines+1]="ORDONNANCES"
    for _,o in ipairs(case.orders or {}) do
      for _,l in ipairs(common.wrap((o.id or "?").." ["..(o.status or "?").."] "..(o.orderType or ""),25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap(o.subject or "",25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap("Sceau: "..(o.seal or "-"),25)) do lines[#lines+1]=l end
      lines[#lines+1]=""
    end
  end

  if #(case.judgments or {})>0 then
    lines[#lines+1]="JUGEMENTS"
    for _,j in ipairs(case.judgments or {}) do
      for _,l in ipairs(common.wrap((j.id or "?").." / "..(j.date or "").." / "..(j.judge or ""),25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap("Decision: "..(j.verdict or ""),25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap("Sceau: "..(j.seal or "-"),25)) do lines[#lines+1]=l end
      lines[#lines+1]=""
    end
  end

  if #(case.appeals or {})>0 then
    lines[#lines+1]="APPELS"
    for _,a in ipairs(case.appeals or {}) do
      for _,l in ipairs(common.wrap((a.id or "?").." ["..(a.status or "?").."] "..(a.appellant or ""),25)) do lines[#lines+1]=l end
      if a.result then for _,l in ipairs(common.wrap("Decision: "..a.result,25)) do lines[#lines+1]=l end end
      if a.decisionSeal then for _,l in ipairs(common.wrap("Sceau: "..a.decisionSeal,25)) do lines[#lines+1]=l end end
      lines[#lines+1]=""
    end
  end

  append(lines,"DERNIERE MAJ",case.updatedAt or case.createdAt or "-",25)
  return printLines(case.id or "NC-CASE",lines)
end

function P.judgment(case,judgment)
  if not case or not judgment then return false,"Jugement introuvable." end
  local lines={}
  append(lines,"JUGEMENT NATIONAL",case.id.." / "..(judgment.id or ""),25)
  append(lines,"DOSSIER",case.title or "",25)
  append(lines,"JUGE",judgment.judge or "-",25)
  append(lines,"DATE",judgment.date or "-",25)
  append(lines,"DECISION",judgment.verdict or "",25)
  append(lines,"MOTIVATION",judgment.reasoning or "",25)
  append(lines,"SANCTIONS / MESURES",judgment.sanctions or "-",25)
  lines[#lines+1]="ARTICLES FIGES"
  for _,law in ipairs(judgment.citedArticleVersions or {}) do
    for _,l in ipairs(common.wrap((law.display_reference or law.id or "?").." v"..tostring(law.version or "?").." / "..(law.title or ""),25)) do lines[#lines+1]=l end
  end
  lines[#lines+1]=""
  append(lines,"SCEAU",judgment.seal or "-",25)
  return printLines((case.id or "NC-CASE").." JUGEMENT",lines)
end


function P.session(sess)
  if not sess then return false,"Session introuvable." end
  local lines={}
  append(lines,"SESSION NATIONALE",sess.id.." / "..(sess.title or ""),25)
  append(lines,"TYPE / STATUT",(sess.sessionType or "-").." / "..(sess.status or "-"),25)
  append(lines,"VISIBILITE",sess.visibility or "-",25)
  append(lines,"DATE / HEURE",sess.scheduledFor or "-",25)
  append(lines,"LIEU",sess.location or "-",25)
  append(lines,"DESCRIPTION",sess.description or "",25)
  append(lines,"SCEAU CONVOCATION",sess.convocationSeal or "-",25)

  lines[#lines+1]="ORDRE DU JOUR"
  for _,item in ipairs(sess.agenda or {}) do
    for _,l in ipairs(common.wrap((item.id or "?").." ["..(item.status or "?").."] "..(item.kind or "").." "..(item.ref or ""),25)) do lines[#lines+1]=l end
    for _,l in ipairs(common.wrap(item.title or "",25)) do lines[#lines+1]=l end
    if item.sessionNotes and item.sessionNotes~="" then
      for _,l in ipairs(common.wrap("Notes: "..item.sessionNotes,25)) do lines[#lines+1]=l end
    end
    lines[#lines+1]=""
  end

  lines[#lines+1]="PRESENCES"
  local attendance={}
  for _,row in pairs(sess.attendance or {}) do attendance[#attendance+1]=row end
  table.sort(attendance,function(a,b) return tostring(a.identity)<tostring(b.identity) end)
  for _,row in ipairs(attendance) do
    for _,l in ipairs(common.wrap((row.identity or "?").." / "..(row.role or "?")..
      (row.ministryCode and (" / "..row.ministryCode) or "").." / "..(row.checkedInAt or ""),25)) do
      lines[#lines+1]=l
    end
  end
  if #attendance==0 then lines[#lines+1]="Aucune presence enregistree." end
  lines[#lines+1]=""

  if sess.openSeal then append(lines,"SCEAU OUVERTURE",sess.openSeal,25) end
  if sess.minutes then append(lines,"PROCES-VERBAL",sess.minutes,25) end
  if sess.conclusions then append(lines,"CONCLUSIONS",sess.conclusions,25) end
  if sess.closeSeal then append(lines,"SCEAU DE CLOTURE",sess.closeSeal,25) end
  if sess.cancelReason then append(lines,"ANNULATION",sess.cancelReason.."\n"..(sess.cancelSeal or "-"),25) end
  return printLines(sess.id or "NC-SESSION",lines)
end


function P.gazette(row)
  if not row then return false,"Publication introuvable." end
  local lines={}
  append(lines,"JOURNAL OFFICIEL",row.id or "-",25)
  append(lines,"NATURE",row.kind or "-",25)
  append(lines,"OBJET",row.objectId or "-",25)
  append(lines,"TITRE",row.title or "",25)
  append(lines,"RESUME",row.summary or "",25)
  append(lines,"VISIBILITE",row.visibility or "internal",25)
  append(lines,"PUBLICATION",(row.publishedAt or "-").." / "..(row.publishedBy or "-"),25)
  append(lines,"SCEAU DE L'ACTE SOURCE",row.sourceSeal or "-",25)
  append(lines,"SCEAU DU JOURNAL",row.seal or "-",25)
  return printLines(row.id or "NC-GAZ",lines)
end


function P.organization(o)
  if not o then return false,"Organisation introuvable." end
  local lines={}
  append(lines,"ORGANISATION",o.id.." / "..(o.name or ""),25)
  append(lines,"TYPE / STATUT",(o.kind or "-").." / "..(o.status or "-"),25)
  append(lines,"ACTIVITE",o.activity or "",25)
  append(lines,"SIEGE / ADRESSE",o.registeredAddress or "-",25)
  local owners={}
  for _,x in ipairs(o.owners or {}) do owners[#owners+1]=(x.citizenId or "?").." / "..(x.identity or "") end
  append(lines,"TITULAIRES / PROPRIETAIRES",#owners>0 and table.concat(owners,"\n") or "Aucun enregistre",25)
  append(lines,"IMMATRICULATION",(o.createdAt or "-").." / "..(o.createdBy or "-"),25)
  append(lines,"SCEAU",o.registrationSeal or "-",25)
  if #(o.history or {})>0 then
    lines[#lines+1]="HISTORIQUE"
    for _,h in ipairs(o.history or {}) do
      for _,l in ipairs(common.wrap((h.at or "").." / "..(h.event or "").." / "..(h.by or "").." / "..(h.oldStatus or "").." -> "..(h.newStatus or ""),25)) do
        lines[#lines+1]=l
      end
      if h.seal then for _,l in ipairs(common.wrap("Sceau: "..h.seal,25)) do lines[#lines+1]=l end end
      lines[#lines+1]=""
    end
  end
  return printLines(o.id or "NC-ORG",lines)
end

function P.license(l)
  if not l then return false,"Licence introuvable." end
  local lines={}
  append(lines,"LICENCE NATIONALE",l.id.." / "..(l.title or ""),25)
  append(lines,"TYPE / STATUT",(l.kind or "-").." / "..(l.status or "-"),25)
  append(lines,"TITULAIRE",(l.holderId or "-").." / "..(l.holderName or ""),25)
  append(lines,"AUTORITE",l.authority or "-",25)
  append(lines,"BASE LEGALE",l.legalBasis or "-",25)
  append(lines,"CONDITIONS",l.conditions or "-",25)
  append(lines,"DELIVREE",(l.issuedAt or "-").." / "..(l.issuedBy or "-"),25)
  append(lines,"EXPIRATION",l.expiresAt or "-",25)
  append(lines,"SCEAU",l.seal or "-",25)
  if #(l.history or {})>0 then
    lines[#lines+1]="HISTORIQUE"
    for _,h in ipairs(l.history or {}) do
      for _,line in ipairs(common.wrap((h.at or "").." / "..(h.event or "").." / "..(h.old or "").." -> "..(h.new or "").." / "..(h.reason or ""),25)) do lines[#lines+1]=line end
      if h.seal then for _,line in ipairs(common.wrap("Sceau: "..h.seal,25)) do lines[#lines+1]=line end end
      lines[#lines+1]=""
    end
  end
  return printLines(l.id or "NC-LIC",lines)
end

function P.fine(fine)
  if not fine then return false,"Amende introuvable." end
  local lines={}
  append(lines,"AMENDE NATIONALE",fine.id or "",25)
  append(lines,"CITOYEN",(fine.citizenId or "-").." / "..(fine.citizenIdentity or ""),25)
  append(lines,"STATUT",fine.status or "-",25)
  append(lines,"ARTICLE",(fine.articleDisplay or fine.articleRef or "-").." / v"..tostring(fine.articleVersion or "?"),25)
  append(lines,"MOTIF",fine.reason or "",25)
  append(lines,"PENALITE",tostring(fine.penaltyUnits or 0).." UP"..((fine.amountText and fine.amountText~="") and (" / "..fine.amountText) or ""),25)
  append(lines,"EMISSION",(fine.issuedAt or "-").." / "..(fine.issuedBy or "-"),25)
  if fine.contestReason then append(lines,"CONTESTATION",fine.contestReason,25) end
  if fine.contestDecision then append(lines,"DECISION",fine.contestDecision.." / "..(fine.contestDecisionReason or ""),25) end
  if fine.paidAt then append(lines,"PAIEMENT",(fine.paidAt or "").." / "..(fine.paymentRef or "-"),25) end
  if fine.voidReason then append(lines,"ANNULATION",fine.voidReason,25) end
  append(lines,"SCEAU",fine.seal or "-",25)
  return printLines(fine.id or "NC-FINE",lines)
end

function P.citizenRecord(record)
  if not record or not record.citizen then return false,"Dossier citoyen introuvable." end
  local cit=record.citizen
  local lines={}
  append(lines,"DOSSIER CITOYEN",cit.id.." / "..(cit.displayName or cit.identity or ""),25)
  append(lines,"IDENTITE",cit.identity or "",25)
  append(lines,"STATUT",cit.status or "",25)
  append(lines,"SCEAU CIVIL",cit.seal or "-",25)

  lines[#lines+1]="LICENCES"
  for _,l in ipairs(record.licenses or {}) do
    for _,x in ipairs(common.wrap((l.id or "").." ["..(l.status or "").."] "..(l.title or l.kind or ""),25)) do lines[#lines+1]=x end
  end
  if #(record.licenses or {})==0 then lines[#lines+1]="Aucune" end
  lines[#lines+1]=""

  lines[#lines+1]="AMENDES"
  for _,f in ipairs(record.fines or {}) do
    for _,x in ipairs(common.wrap((f.id or "").." ["..(f.status or "").."] "..tostring(f.penaltyUnits or 0).." UP / "..(f.articleDisplay or f.articleRef or ""),25)) do lines[#lines+1]=x end
  end
  if #(record.fines or {})==0 then lines[#lines+1]="Aucune" end
  lines[#lines+1]=""

  lines[#lines+1]="ORGANISATIONS"
  for _,o in ipairs(record.organizations or {}) do
    for _,x in ipairs(common.wrap((o.id or "").." ["..(o.status or "").."] "..(o.name or ""),25)) do lines[#lines+1]=x end
  end
  if #(record.organizations or {})==0 then lines[#lines+1]="Aucune" end
  lines[#lines+1]=""

  lines[#lines+1]="DECISIONS JUDICIAIRES"
  for _,j in ipairs(record.judgments or {}) do
    for _,x in ipairs(common.wrap((j.caseId or "").." / "..(j.judgmentId or "").." / "..(j.verdict or ""),25)) do lines[#lines+1]=x end
  end
  if #(record.judgments or {})==0 then lines[#lines+1]="Aucune" end
  lines[#lines+1]=""

  return printLines(cit.id.." DOSSIER",lines)
end


function P.request(req)
  if not req then return false,"Demande introuvable." end
  local lines={}
  append(lines,"DEMANDE ADMINISTRATIVE",req.id.." / "..(req.title or ""),25)
  append(lines,"TYPE / STATUT",(req.requestType or "-").." / "..(req.status or "-"),25)
  append(lines,"DEMANDEUR",(req.applicantCitizenId or "-").." / "..(req.applicantIdentity or ""),25)
  append(lines,"DESTINATAIRE",req.targetMinistry or "-",25)
  append(lines,"OBJET / MOTIVATION",req.body or "",25)
  append(lines,"BASE LEGALE",req.legalBasis or "-",25)
  if req.payload then
    local p=req.payload
    if req.requestType=="license" then
      append(lines,"LICENCE DEMANDEE",(p.kind or "-").." / "..(p.title or ""),25)
      append(lines,"EXPIRATION SOUHAITEE",p.expiresAt or "-",25)
      append(lines,"CONDITIONS SOUHAITEES",p.conditionsRequested or "-",25)
    elseif req.requestType=="organization" then
      append(lines,"ORGANISATION",(p.name or "-").." / "..(p.kind or "-"),25)
      append(lines,"ACTIVITE",p.activity or "-",25)
      append(lines,"SIEGE",p.registeredAddress or "-",25)
    end
  end
  append(lines,"DEPOT",(req.createdAt or "-").." / "..(req.createdBy or "-"),25)
  append(lines,"SCEAU DE DEPOT",req.seal or "-",25)
  if req.decision then
    append(lines,"DECISION",(req.decision or "").." / "..(req.decisionReason or ""),25)
    append(lines,"DECIDEE",(req.decidedAt or "-").." / "..(req.decidedBy or "-"),25)
    append(lines,"OBJET CREE",req.resultObjectId or "-",25)
    append(lines,"SCEAU DE DECISION",req.decisionSeal or "-",25)
  end
  if #(req.history or {})>0 then
    lines[#lines+1]="HISTORIQUE"
    for _,h in ipairs(req.history or {}) do
      for _,x in ipairs(common.wrap((h.at or "").." / "..(h.event or "").." / "..(h.by or "").." / "..(h.details or ""),25)) do lines[#lines+1]=x end
      if h.seal then for _,x in ipairs(common.wrap("Sceau: "..h.seal,25)) do lines[#lines+1]=x end end
      lines[#lines+1]=""
    end
  end
  return printLines(req.id or "NC-REQ",lines)
end

return P
