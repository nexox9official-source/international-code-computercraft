local common = dofile("/international_code/common.lua")
local P = {}

local function getPrinter()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "printer" then return peripheral.wrap(name), name end
  end
  return nil, nil
end

function P.available()
  local p, name = getPrinter()
  return p ~= nil, name
end

local function appendWrapped(lines, label, text, width)
  if label and label ~= "" then lines[#lines + 1] = label end
  local wrapped = common.wrap(text or "", width)
  for _, line in ipairs(wrapped) do lines[#lines + 1] = line end
  lines[#lines + 1] = ""
end

local function printLines(title, lines)
  local printer = getPrinter()
  if not printer then return false, "Aucune imprimante connectee." end
  local width, height = 25, 21
  if printer.getPageSize then
    local ok, w, h = pcall(printer.getPageSize)
    if ok and w and h then width, height = w, h end
  end
  local bodyHeight = math.max(5, height - 3)
  local pageCount = math.max(1, math.ceil(#lines / bodyHeight))
  local cursor = 1
  for page = 1, pageCount do
    if not printer.newPage() then return false, "Papier ou encre insuffisants." end
    if printer.setPageTitle then pcall(printer.setPageTitle, common.fit(title, 32)) end
    printer.setCursorPos(1,1)
    printer.write(common.fit("UNS / COUR INTERNATIONALE", width))
    local y = 2
    while y <= bodyHeight + 1 and cursor <= #lines do
      printer.setCursorPos(1,y)
      printer.write(common.fit(lines[cursor], width))
      cursor = cursor + 1
      y = y + 1
    end
    printer.setCursorPos(1,height)
    printer.write(common.fit("Page " .. page .. "/" .. pageCount, width))
    if not printer.endPage() then return false, "Impossible de finaliser la page." end
  end
  return true, pageCount
end

function P.law(law)
  local lines = {}
  appendWrapped(lines, law.ref .. " / v" .. tostring(law.version or 1), law.title, 25)
  appendWrapped(lines, "LIVRE", law.book or "Non classe", 25)
  appendWrapped(lines, "TITRE", law.section or "Non classe", 25)
  appendWrapped(lines, "STATUT", law.status or "inconnu", 25)
  appendWrapped(lines, "TEXTE", law.body or "", 25)
  appendWrapped(lines, "MISE A JOUR", law.updatedAt or law.createdAt or "", 25)
  if law.lastChangeReason and law.lastChangeReason~="" then
    appendWrapped(lines, "MOTIF DERNIERE MODIFICATION", law.lastChangeReason, 25)
  end
  return printLines(law.ref or "ARTICLE", lines)
end

function P.caseFile(case)
  local lines = {}
  appendWrapped(lines, case.id, case.title or "Dossier sans titre", 25)
  appendWrapped(lines, "STATUT", case.status or "ouvert", 25)
  appendWrapped(lines, "DEMANDEUR", case.complainant or "-", 25)
  appendWrapped(lines, "MIS EN CAUSE", case.accused or "-", 25)
  appendWrapped(lines, "CONTEXTE", case.summary or "", 25)

  lines[#lines+1] = "FAITS"
  for i, f in ipairs(case.facts or {}) do
    for _, l in ipairs(common.wrap(i .. ". " .. (f.text or ""), 25)) do lines[#lines+1] = l end
  end
  lines[#lines+1] = ""

  lines[#lines+1] = "PREUVES"
  for i, e in ipairs(case.evidence or {}) do
    for _, l in ipairs(common.wrap(i .. ". " .. (e.label or "Preuve") .. ": " .. (e.description or ""), 25)) do lines[#lines+1] = l end
  end
  lines[#lines+1] = ""

  appendWrapped(lines, "ARTICLES CITES", table.concat(case.citedArticles or {}, ", "), 25)

  lines[#lines+1] = "JUGEMENTS"
  for i, j in ipairs(case.judgments or {}) do
    for _, l in ipairs(common.wrap("Jugement " .. i .. " - " .. (j.date or ""), 25)) do lines[#lines+1] = l end
    for _, l in ipairs(common.wrap("Decision: " .. (j.verdict or ""), 25)) do lines[#lines+1] = l end
    for _, l in ipairs(common.wrap("Motifs: " .. (j.reasoning or ""), 25)) do lines[#lines+1] = l end
    for _, l in ipairs(common.wrap("Sanctions: " .. (j.sanctions or ""), 25)) do lines[#lines+1] = l end
    lines[#lines+1] = ""
  end

  if case.hearings and #case.hearings>0 then
    lines[#lines+1]="AUDIENCES"
    for _,h in ipairs(case.hearings) do
      for _,l in ipairs(common.wrap((h.id or "?").." "..(h.scheduledFor or "").." ["..(h.status or "?").."]",25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap(h.subject or "",25)) do lines[#lines+1]=l end
      if h.recordSeal then
        for _,l in ipairs(common.wrap("PV: "..(h.recordSeal or "-"),25)) do lines[#lines+1]=l end
      end
      lines[#lines+1]=""
    end
  end

  if case.orders and #case.orders>0 then
    lines[#lines+1]="ORDONNANCES / MANDATS"
    for _,o in ipairs(case.orders) do
      for _,l in ipairs(common.wrap((o.id or "?").." "..(o.orderType or "").." ["..(o.status or "?").."]",25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap(o.subject or "",25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap("Sceau: "..(o.seal or "-"),25)) do lines[#lines+1]=l end
      lines[#lines+1]=""
    end
  end

  if case.appeals and #case.appeals>0 then
    lines[#lines+1]="APPELS"
    for _,a in ipairs(case.appeals) do
      for _,l in ipairs(common.wrap((a.id or "?").." "..(a.appellant or "").." ["..(a.status or "?").."]",25)) do lines[#lines+1]=l end
      if a.result then for _,l in ipairs(common.wrap("Decision: "..a.result,25)) do lines[#lines+1]=l end end
      if a.decisionSeal then for _,l in ipairs(common.wrap("Sceau: "..a.decisionSeal,25)) do lines[#lines+1]=l end end
    end
    lines[#lines+1]=""
  end

  if case.timeline and #case.timeline>0 then
    lines[#lines+1]="CHRONOLOGIE"
    for i,event in ipairs(case.timeline) do
      local head=string.format("%d. %s - %s",i,event.at or "",event.title or event.kind or "Evenement")
      for _,l in ipairs(common.wrap(head,25)) do lines[#lines+1]=l end
      if event.details and event.details~="" then
        for _,l in ipairs(common.wrap(event.details,25)) do lines[#lines+1]=l end
      end
    end
    lines[#lines+1]=""
  end

  appendWrapped(lines, "DERNIERE MAJ", case.updatedAt or case.createdAt or "", 25)
  return printLines(case.id or "DOSSIER", lines)
end


function P.judgment(case, judgment)
  if not judgment then return false, "Aucun jugement selectionne." end
  local lines={}
  appendWrapped(lines, "ARRET / JUGEMENT", case.id or "-", 25)
  appendWrapped(lines, "AFFAIRE", case.title or "Dossier sans titre", 25)
  appendWrapped(lines, "DEMANDEUR", case.complainant or "-", 25)
  appendWrapped(lines, "MIS EN CAUSE", case.accused or "-", 25)
  appendWrapped(lines, "JUGE", judgment.judge or "-", 25)
  appendWrapped(lines, "DATE", judgment.date or "-", 25)
  appendWrapped(lines, "DECISION", judgment.verdict or "", 25)
  appendWrapped(lines, "MOTIVATION", judgment.reasoning or "", 25)
  appendWrapped(lines, "SANCTIONS / REPARATIONS", judgment.sanctions or "", 25)

  local refs={}
  if judgment.articleSnapshot and #judgment.articleSnapshot>0 then
    for _,a in ipairs(judgment.articleSnapshot) do
      local suffix=a.version and (" v"..tostring(a.version)) or ""
      refs[#refs+1]=(a.ref or "?")..suffix.." ["..tostring(a.status or "?").."] "..(a.title or "")
    end
  else
    for _,ref in ipairs(judgment.citedArticles or {}) do refs[#refs+1]=ref end
  end
  appendWrapped(lines, "ARTICLES APPLIQUES", table.concat(refs,"\n"), 25)
  appendWrapped(lines, "CARACTERE", judgment.final and "Decision finale" or "Decision intermediaire", 25)
  appendWrapped(lines, "SCEAU OFFICIEL", judgment.seal or "Ancienne decision sans sceau v0.4", 25)
  return printLines((case.id or "DOSSIER").."-J"..tostring(judgment.id or 1), lines)
end

function P.timeline(case)
  local lines={}
  appendWrapped(lines, "CHRONOLOGIE", case.id or "-", 25)
  appendWrapped(lines, "AFFAIRE", case.title or "Dossier sans titre", 25)
  for i,event in ipairs(case.timeline or {}) do
    local head=string.format("%d. %s / %s",i,event.at or "",event.title or event.kind or "Evenement")
    for _,l in ipairs(common.wrap(head,25)) do lines[#lines+1]=l end
    local meta=(event.by or "?").." ["..(event.role or "?").."]"
    for _,l in ipairs(common.wrap(meta,25)) do lines[#lines+1]=l end
    if event.details and event.details~="" then
      for _,l in ipairs(common.wrap(event.details,25)) do lines[#lines+1]=l end
    end
    lines[#lines+1]=""
  end
  return printLines((case.id or "DOSSIER").."-CHRONO",lines)
end


function P.hearingNotice(case, hearing)
  if not hearing then return false,"Audience introuvable." end
  local lines={}
  appendWrapped(lines,"AVIS D'AUDIENCE",case.id or "-",25)
  appendWrapped(lines,"AFFAIRE",case.title or "-",25)
  appendWrapped(lines,"OBJET",hearing.subject or "-",25)
  appendWrapped(lines,"DATE / HEURE",hearing.scheduledFor or "-",25)
  appendWrapped(lines,"LIEU",hearing.location or "-",25)
  appendWrapped(lines,"STATUT",hearing.status or "-",25)
  appendWrapped(lines,"NOTES",hearing.notes or "",25)
  appendWrapped(lines,"EMIS PAR",hearing.createdBy or "-",25)
  appendWrapped(lines,"SCEAU OFFICIEL",hearing.seal or "-",25)
  return printLines((case.id or "DOSSIER").."-"..(hearing.id or "AUDIENCE"),lines)
end

function P.order(case, order)
  if not order then return false,"Ordonnance introuvable." end
  local lines={}
  appendWrapped(lines,"ORDONNANCE / MANDAT",case.id or "-",25)
  appendWrapped(lines,"REFERENCE",order.id or "-",25)
  appendWrapped(lines,"TYPE",order.orderType or "order",25)
  appendWrapped(lines,"AFFAIRE",case.title or "-",25)
  appendWrapped(lines,"OBJET",order.subject or "-",25)
  appendWrapped(lines,"CONTENU",order.body or "",25)
  appendWrapped(lines,"STATUT",order.status or "-",25)
  appendWrapped(lines,"EXPIRATION",order.expiresAt or "-",25)
  appendWrapped(lines,"JUGE",order.createdBy or "-",25)
  appendWrapped(lines,"DATE",order.createdAt or "-",25)
  appendWrapped(lines,"SCEAU OFFICIEL",order.seal or "-",25)
  return printLines((case.id or "DOSSIER").."-"..(order.id or "ORDRE"),lines)
end

function P.bill(bill)
  if not bill then return false,"Proposition introuvable." end
  local lines={}
  appendWrapped(lines,"PROPOSITION LEGISLATIVE",bill.id or "-",25)
  appendWrapped(lines,"TITRE",bill.title or "-",25)
  appendWrapped(lines,"ETAPE",bill.stage or "-",25)
  appendWrapped(lines,"TYPE",bill.proposalType or "-",25)
  if bill.targetRef and bill.targetRef~="" then appendWrapped(lines,"ARTICLE CIBLE",bill.targetRef,25) end
  if bill.targetRefs and #bill.targetRefs>0 then appendWrapped(lines,"ARTICLES CIBLES",table.concat(bill.targetRefs,"\n"),25) end
  appendWrapped(lines,"RESUME",bill.summary or "",25)
  appendWrapped(lines,"TITRE PROPOSE",bill.proposedTitle or "",25)
  appendWrapped(lines,"TEXTE PROPOSE",bill.proposedBody or "",25)
  appendWrapped(lines,"LIVRE",bill.proposedBook or "",25)
  appendWrapped(lines,"SECTION",bill.proposedSection or "",25)
  appendWrapped(lines,"REGLE DE VOTE",bill.threshold or "",25)
  if bill.tally then
    appendWrapped(lines,"RESULTATS",
      "Pour: "..tostring(bill.tally.yes or 0)..
      " / Contre: "..tostring(bill.tally.no or 0)..
      " / Abstention: "..tostring(bill.tally.abstain or 0)..
      " / Membres: "..tostring(bill.tally.eligible or 0)..
      " / Quorum: "..(bill.tally.quorumMet and "oui" or "non"),25)
  end
  if bill.resultSeal then appendWrapped(lines,"SCEAU DU SCRUTIN",bill.resultSeal,25) end
  if bill.enactedRefs and #bill.enactedRefs>1 then
    appendWrapped(lines,"ARTICLES PROMULGUES",table.concat(bill.enactedRefs,"\n"),25)
  elseif bill.enactedRef then
    appendWrapped(lines,"PROMULGUE",bill.enactedRef,25)
  end
  if bill.enactmentSeal then appendWrapped(lines,"SCEAU DE PROMULGATION",bill.enactmentSeal,25) end
  return printLines(bill.id or "PROPOSITION",lines)
end


function P.appeal(case, appeal)
  if not appeal then return false,"Appel introuvable." end
  local lines={}
  appendWrapped(lines,"ACTE D'APPEL",case.id or "-",25)
  appendWrapped(lines,"REFERENCE",appeal.id or "-",25)
  appendWrapped(lines,"AFFAIRE",case.title or "-",25)
  appendWrapped(lines,"APPELANT",appeal.appellant or "-",25)
  appendWrapped(lines,"MOTIFS",appeal.grounds or "",25)
  appendWrapped(lines,"DEMANDE",appeal.request or "",25)
  appendWrapped(lines,"DEPOT",(appeal.filedAt or "").." / "..(appeal.filedBy or ""),25)
  appendWrapped(lines,"STATUT",appeal.status or "-",25)
  appendWrapped(lines,"SCEAU DEPOT",appeal.seal or "-",25)
  if appeal.result then
    appendWrapped(lines,"DECISION D'APPEL",appeal.result,25)
    appendWrapped(lines,"MOTIVATION",appeal.reasoning or "",25)
    appendWrapped(lines,"JUGE D'APPEL",(appeal.decidedBy or "").." / "..(appeal.decidedAt or ""),25)
    appendWrapped(lines,"SCEAU DECISION",appeal.decisionSeal or "-",25)
  end
  return printLines((case.id or "DOSSIER").."-"..(appeal.id or "APPEL"),lines)
end


function P.treaty(treaty)
  if not treaty then return false,"Traite introuvable." end
  local lines={}
  appendWrapped(lines,"TRAITE INTERNATIONAL",treaty.id or "-",25)
  appendWrapped(lines,"TITRE",treaty.title or "-",25)
  appendWrapped(lines,"TYPE",treaty.treatyType or "-",25)
  appendWrapped(lines,"VERSION","v"..tostring(treaty.version or 1),25)
  appendWrapped(lines,"STATUT",treaty.stage or "-",25)
  appendWrapped(lines,"ETATS PARTIES",table.concat(treaty.parties or {},"\n"),25)
  appendWrapped(lines,"RESUME",treaty.summary or "",25)
  appendWrapped(lines,"TEXTE",treaty.body or "",25)
  if treaty.signatureTextSeal then appendWrapped(lines,"SCEAU DU TEXTE",treaty.signatureTextSeal,25) end

  lines[#lines+1]="SIGNATURES"
  local sigs={}
  for stateId,sig in pairs(treaty.signatures or {}) do
    sigs[#sigs+1]={stateId=stateId,sig=sig}
  end
  table.sort(sigs,function(a,b) return a.stateId<b.stateId end)
  for _,entry in ipairs(sigs) do
    local sig=entry.sig
    for _,l in ipairs(common.wrap((sig.stateName or entry.stateId).." / "..(sig.at or ""),25)) do lines[#lines+1]=l end
    for _,l in ipairs(common.wrap("Sceau: "..(sig.seal or "-"),25)) do lines[#lines+1]=l end
    lines[#lines+1]=""
  end

  if treaty.activationSeal then
    appendWrapped(lines,"ENTREE EN VIGUEUR",treaty.effectiveAt or "-",25)
    appendWrapped(lines,"SCEAU D'ACTIVATION",treaty.activationSeal,25)
  end
  if treaty.terminationReason then
    appendWrapped(lines,"FIN DU TRAITE",(treaty.terminatedAt or "").." / "..treaty.terminationReason,25)
    appendWrapped(lines,"SCEAU DE FIN",treaty.terminationSeal or "-",25)
  end
  return printLines(treaty.id or "TRAITE",lines)
end


function P.enforcement(e)
  if not e then return false,"Mesure d'execution introuvable." end
  local lines={}
  appendWrapped(lines,"MESURE D'EXECUTION",e.id or "-",25)
  appendWrapped(lines,"TYPE",e.enforcementType or "-",25)
  appendWrapped(lines,"STATUT",e.status or "-",25)
  appendWrapped(lines,"CIBLE",e.targetName or "-",25)
  if e.targetStateId and e.targetStateId~="" then appendWrapped(lines,"ETAT",e.targetStateId,25) end
  if e.caseId and e.caseId~="" then appendWrapped(lines,"DOSSIER",e.caseId,25) end
  if e.judgmentId and e.judgmentId~="" then appendWrapped(lines,"JUGEMENT",e.judgmentId,25) end
  appendWrapped(lines,"OBJET",e.summary or "",25)
  appendWrapped(lines,"CONDITIONS",e.terms or "",25)
  if e.amount and e.amount~="" then appendWrapped(lines,"MONTANT",e.amount,25) end
  if e.deadline and e.deadline~="" then appendWrapped(lines,"ECHEANCE",e.deadline,25) end
  appendWrapped(lines,"VISIBILITE",e.visibility or "restricted",25)
  appendWrapped(lines,"ORDONNE PAR",(e.createdBy or "-").." / "..(e.createdAt or "-"),25)
  appendWrapped(lines,"SCEAU INITIAL",e.seal or "-",25)

  if e.progress and #e.progress>0 then
    lines[#lines+1]="SUIVI D'EXECUTION"
    for _,row in ipairs(e.progress) do
      for _,l in ipairs(common.wrap("#"..tostring(row.id or "?").." "..(row.at or "").." / "..(row.by or "?"),25)) do lines[#lines+1]=l end
      for _,l in ipairs(common.wrap(row.note or "",25)) do lines[#lines+1]=l end
      if row.reference and row.reference~="" then
        for _,l in ipairs(common.wrap("Ref: "..row.reference,25)) do lines[#lines+1]=l end
      end
      for _,l in ipairs(common.wrap("Sceau: "..(row.seal or "-"),25)) do lines[#lines+1]=l end
      lines[#lines+1]=""
    end
  end

  if e.statusHistory and #e.statusHistory>0 then
    lines[#lines+1]="HISTORIQUE DE STATUT"
    for _,row in ipairs(e.statusHistory) do
      for _,l in ipairs(common.wrap((row.at or "").." "..(row.from or "?").." -> "..(row.to or "?"),25)) do lines[#lines+1]=l end
      if row.reason and row.reason~="" then
        for _,l in ipairs(common.wrap(row.reason,25)) do lines[#lines+1]=l end
      end
      for _,l in ipairs(common.wrap("Sceau: "..(row.seal or "-"),25)) do lines[#lines+1]=l end
      lines[#lines+1]=""
    end
  end

  return printLines(e.id or "EXECUTION",lines)
end


function P.hearingMinutes(case, hearing)
  if not hearing then return false,"Audience introuvable." end
  local lines={}
  appendWrapped(lines,"PROCES-VERBAL D'AUDIENCE",case.id or "-",25)
  appendWrapped(lines,"REFERENCE",hearing.id or "-",25)
  appendWrapped(lines,"AFFAIRE",case.title or "-",25)
  appendWrapped(lines,"OBJET",hearing.subject or "-",25)
  appendWrapped(lines,"DATE / HEURE",hearing.scheduledFor or "-",25)
  appendWrapped(lines,"LIEU",hearing.location or "-",25)
  appendWrapped(lines,"PARTICIPANTS",hearing.participants or "-",25)
  appendWrapped(lines,"COMPTE RENDU",hearing.minutes or "",25)
  appendWrapped(lines,"ISSUE / SUITE",hearing.outcome or "-",25)
  appendWrapped(lines,"ENREGISTRE PAR",(hearing.recordedBy or "-").." / "..(hearing.recordedAt or "-"),25)
  appendWrapped(lines,"SCEAU DU PV",hearing.recordSeal or "-",25)
  return printLines((case.id or "DOSSIER").."-"..(hearing.id or "AUDIENCE").."-PV",lines)
end


function P.resolution(r)
  if not r then return false,"Resolution introuvable." end
  local lines={}
  appendWrapped(lines,"RESOLUTION DE L'UNION",r.id or "-",25)
  appendWrapped(lines,"TITRE",r.title or "-",25)
  appendWrapped(lines,"TYPE",r.resolutionType or "-",25)
  appendWrapped(lines,"ETAPE",r.stage or "-",25)
  if r.targetStateId and r.targetStateId~="" then appendWrapped(lines,"ETAT CIBLE",r.targetStateId,25) end
  if r.linkedCaseId and r.linkedCaseId~="" then appendWrapped(lines,"DOSSIER LIE",r.linkedCaseId,25) end
  appendWrapped(lines,"RESUME",r.summary or "",25)
  appendWrapped(lines,"TEXTE",r.body or "",25)
  appendWrapped(lines,"REGLE DE VOTE",r.threshold or "",25)

  if r.tally then
    appendWrapped(lines,"SCRUTIN",
      "Pour: "..tostring(r.tally.yes or 0)..
      " / Contre: "..tostring(r.tally.no or 0)..
      " / Abstention: "..tostring(r.tally.abstain or 0)..
      " / Participation: "..tostring(r.tally.participation or 0).."/"..tostring(r.tally.eligible or 0)..
      " / Quorum: "..(r.tally.quorumMet and "oui" or "non"),25)
  end

  if r.resultSeal then appendWrapped(lines,"SCEAU DU SCRUTIN",r.resultSeal,25) end

  if r.createsEnforcement then
    appendWrapped(lines,"EXECUTION PREVUE",
      (r.enforcementType or "other")..
      ((r.enforcementAmount and r.enforcementAmount~="") and (" / "..r.enforcementAmount) or "")..
      ((r.enforcementDeadline and r.enforcementDeadline~="") and (" / echeance "..r.enforcementDeadline) or ""),25)
    appendWrapped(lines,"CONDITIONS D'EXECUTION",r.enforcementTerms or "",25)
  end

  if r.enforcementId then appendWrapped(lines,"MESURE D'EXECUTION",r.enforcementId,25) end
  if r.executionSeal then appendWrapped(lines,"SCEAU D'EXECUTION",r.executionSeal,25) end
  return printLines(r.id or "RESOLUTION",lines)
end

return P
