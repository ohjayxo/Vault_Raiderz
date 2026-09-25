export const meta = {
  name: 'ui-pass-review',
  description: 'Review the UI overhaul diff for runtime bugs by area, then adversarially verify each finding (read-only)',
  phases: [{ title: 'Review', detail: '6 reviewers, one per area' }, { title: 'Verify', detail: 'a skeptic per finding' }],
}

const CONTEXT = `
We cannot run Roblox Studio here, so you are the only check before the owner tests. The working tree has UNCOMMITTED changes (run \`git diff\` for your files; \`git diff HEAD -- <file>\` shows the change against the last commit). A large UI overhaul was just written: shared window frame (UiStyle.window: header strip + inset well + red X), UiStyle.topStack / dock / thumbColumn shared ScreenGuis, new toast spots, new item rows, etc. Luau type-checking already passes (\`luau-lsp analyze\` is clean), so DO NOT report type errors. Hunt for RUNTIME and LAYOUT bugs the type checker cannot see:
- Roblox UI behaviour: UIListLayout ignoring Position/AnchorPoint of children; AutomaticSize + Size interactions that collapse to 0 or blow up; ZIndex/DisplayOrder overlaps and things covered or made untappable; UIFlexItem misuse; ScrollingFrame canvas problems; rich text tags; Visible toggles that leave gaps or stale state; get-or-create ScreenGui helpers racing.
- Logic: wrong nil handling, a code path that errors at runtime, stale UI after state changes, event handlers connected twice or never, values read before they exist, remote argument/return mismatches between client and server (src/shared/Remotes.luau documents the signatures).
- Design rules from CLAUDE.md: R5 the server is the only authority (client never decides or trusts values), R4 depth hidden from new players (FTUE hides economy/trade/etc.), no magic numbers outside Config, the greybox contract (never touch a Visual folder).
- Phone landscape (~850x390) and portrait (~390x850) fit: text/buttons cut off, controls overlapping, the tap targets under 44px.
Only report things you are reasonably sure are real, with the exact file and line and a concrete failure scenario. Do not report style nits or hypothetical features. Do NOT edit any file. Cap at 8 findings, most severe first. Say so in the summary if you found nothing.`

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          line: { type: 'number' },
          title: { type: 'string' },
          scenario: { type: 'string' },
          severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
          suggestedFix: { type: 'string' },
        },
        required: ['file', 'line', 'title', 'scenario', 'severity', 'suggestedFix'],
      },
    },
    summary: { type: 'string' },
  },
  required: ['findings', 'summary'],
}

const VERDICT = {
  type: 'object',
  properties: {
    real: { type: 'boolean' },
    reasoning: { type: 'string' },
    correctedFix: { type: 'string' },
  },
  required: ['real', 'reasoning', 'correctedFix'],
}

const AREAS = [
  { key: 'shared', files: 'src/shared/UiStyle.luau and the UiStyle block of src/shared/Config.luau (window, topStack, dock, dockButton, thumbColumn, toast, banner, itemRow stripe, sectionHeader summary, setActiveTab, setTileState)', extra: 'Trace how EVERY caller uses these (grep src/client) and check the callers still work: e.g. the header strip vs the close button, the Well vs the scroller z-order, callers that set Position on something now inside a UIListLayout.' },
  { key: 'server', files: 'src/server/Services/EconomyService.luau, src/server/Services/PlayerDataService/Template.luau, src/shared/PlayerDataTypes.luau (SellQuote, NpcSales), src/shared/Remotes.luau (SellUnits, CreditsChanged)', extra: 'Check the new quote fields (ResetsIn, PayoutOne/Ten/All), the EverSold flag (does every code path that rewrites NpcSales keep it? the day-rollover, the rollback path), the extra SellUnits return value, and that every client listener of CreditsChanged and every consumer of the quote (src/client) matches. Money/rounding consistency between the quote payouts and what sell() actually pays.' },
  { key: 'buyer-trade', files: 'src/client/NpcShop.client.luau and src/client/TradeUi.client.luau', extra: 'Check the chip rich text, the countdown loop, the toast, the trade window header/well/footer/warning-strip layout math, the grouped picker rows, the receipt card, and whether hiding the trade window X leaves the window impossible to dismiss in some state.' },
  { key: 'gear-bag', files: 'src/client/GearUi.client.luau and src/client/InventoryUi.client.luau', extra: 'Check the Gear window (title empty at first, no columns now, upgrade buy buttons, toasts), the Bag chrome layout math with the new header strip/well (tabs in header vs own row, content position), the Worn/Spare grouping, arrows, Craft affordability, the Debug button now in the dock.' },
  { key: 'raid-hud', files: 'src/client/RaidUi.client.luau, src/client/CombatInput.client.luau, src/client/AnnouncementBanner.client.luau, src/client/BaseAlerts.client.luau, src/client/VaultMeter.client.luau', extra: 'Check the raid banner block in the shared top stack (banner + timer pill overlay, note, chase bar, grip bar, escort card, tween), lockpick pin dots and how-to timer, the Breach confirm button state, the map key/letters, the thumb column context list for short windows, the Attack button hiding in build mode, the Credits line on the vault meter (FTUE rule 5).' },
  { key: 'build', files: 'src/client/BuildMode.client.luau', extra: 'Check the Build button now living in the shared thumb column ScreenGui (visibility, tappability, DisplayOrder vs the build panel), the Place | Edit tab bar, tiles disabled with reasons (do the client hints match PlotService.place rules?), the vault state fetch, the upgrade button reparenting between infoRow and actionRow, the budget pill on short screens, hidden groups when in Edit mode.' },
]

phase('Review')
const results = await pipeline(
  AREAS,
  a => agent(`Review the ${a.key} area of the Vault Raiderz UI overhaul.\nFiles: ${a.files}\n${a.extra}\n${CONTEXT}`, { label: `review:${a.key}`, phase: 'Review', schema: FINDINGS }),
  (review, a) => {
    if (!review || !review.findings || review.findings.length === 0) return { area: a.key, summary: review ? review.summary : 'reviewer failed', verified: [] }
    return parallel(review.findings.map(f => () =>
      agent(`A reviewer claims this bug in the Vault Raiderz UI overhaul (uncommitted changes; use git diff and read the code). Try to REFUTE it: read the actual code and the Roblox behaviour involved, and decide if it is real. Default to real=false if you cannot construct a concrete failure from the code as written. If real, give a corrected, minimal fix (exact edit) in correctedFix; if not, put "" there.\n\nFile: ${f.file}:${f.line}\nClaim: ${f.title}\nScenario: ${f.scenario}\nSeverity claimed: ${f.severity}\nSuggested fix: ${f.suggestedFix}\n\nDo NOT edit any file.`,
        { label: `verify:${f.file.split('/').pop()}:${f.line}`, phase: 'Verify', schema: VERDICT })
        .then(v => ({ ...f, verdict: v }))
    )).then(verified => ({ area: a.key, summary: review.summary, verified: verified.filter(Boolean) }))
  },
)
return results.filter(Boolean)
