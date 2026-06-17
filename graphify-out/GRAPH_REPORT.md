# Graph Report - SpherePanel  (2026-06-17)

## Corpus Check
- 30 files · ~46,902 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 427 nodes · 518 edges · 30 communities (24 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bf6dc6eb`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]

## God Nodes (most connected - your core abstractions)
1. `MakeCheck()` - 11 edges
2. `MakeSlider()` - 8 edges
3. `M:Refresh()` - 7 edges
4. `BuildModulePage()` - 6 edges
5. `BuildApparence()` - 6 edges
6. `CreateOptions()` - 6 edges
7. `M:Refresh()` - 5 edges
8. `AS()` - 5 edges
9. `hasAS()` - 5 edges
10. `M:Refresh()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `BagsOptions()` --calls--> `Apply()`  [INFERRED]
  Config_UI.lua → Modules/SquareMap.lua

## Import Cycles
- None detected.

## Communities (30 total, 6 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.09
Nodes (8): ApplyIcon(), Blacklisted(), GrabIcon(), HasClick(), M:BuildCustomMenus(), M:CollectAddons(), M:Scan(), M:StealOne()

### Community 1 - "Community 1"
Cohesion: 0.10
Nodes (10): ApplyIcon(), Classify(), CreateEntry(), GetObjLine(), M:AcquireEntry(), M:Init(), M:PrewarmPool(), M:Refresh() (+2 more)

### Community 2 - "Community 2"
Cohesion: 0.06
Nodes (5): clamp(), copyColor(), SP:ApplyModuleAppearance(), SP:GetModuleAppearanceConfig(), SP:ResetModuleAppearance()

### Community 3 - "Community 3"
Cohesion: 0.08
Nodes (18): BagCfg(), ClassKey(), CreateCurrencyRow(), CreateHeader(), CreateSlot(), CreateSub(), Ct(), GroupLabel() (+10 more)

### Community 4 - "Community 4"
Cohesion: 0.24
Nodes (18): AurasOptions(), BagsOptions(), BuildApparence(), BuildComportement(), BuildConditions(), BuildGeneral(), BuildModulePage(), CharacterOptions() (+10 more)

### Community 5 - "Community 5"
Cohesion: 0.09
Nodes (8): IsTradeChannel(), LinkifyURLs(), M:AddMessage(), M:Init(), M:PrimaryKey(), M:RefreshSocial(), NormType(), socialClassColor()

### Community 6 - "Community 6"
Cohesion: 0.11
Nodes (8): CreateRow(), HasSD(), ItemID(), M:Enable(), M:HideNativePopups(), M:Refresh(), WipeList(), ZoneName()

### Community 7 - "Community 7"
Cohesion: 0.12
Nodes (3): lerp(), SP:_TickFree(), SP:_TickSlide()

### Community 8 - "Community 8"
Cohesion: 0.16
Nodes (8): ApplyCooldown(), CountText(), CreateIcon(), Gather(), M:Acquire(), M:Prewarm(), M:Refresh(), SafeDispelName()

### Community 9 - "Community 9"
Cohesion: 0.23
Nodes (8): Abbr(), classHex(), GetChars(), M:Init(), M:Refresh(), ratingHex(), scoreHex(), TierMarkup()

### Community 10 - "Community 10"
Cohesion: 0.19
Nodes (4): CreateBar(), M:Prewarm(), M:Refresh(), ShortNum()

### Community 11 - "Community 11"
Cohesion: 0.23
Nodes (5): HasClick(), IsAddonButton(), M:Collect(), M:Scan(), StealButton()

### Community 12 - "Community 12"
Cohesion: 0.23
Nodes (5): Apply(), M:Enable(), M:OnResize(), SaveMapState(), TargetSide()

### Community 13 - "Community 13"
Cohesion: 0.31
Nodes (6): BuildUnitList(), CreateBar(), M:Init(), M:Prewarm(), M:Rebuild(), UpdateBar()

### Community 16 - "Community 16"
Cohesion: 0.28
Nodes (3): HasBuff(), M:Refresh(), UnitsInGroup()

### Community 17 - "Community 17"
Cohesion: 0.28
Nodes (3): classColor(), CreateRow(), M:Refresh()

### Community 20 - "Community 20"
Cohesion: 0.18
Nodes (3): fmtTime(), M:Refresh(), M:RenderMythicPlus()

### Community 27 - "Community 27"
Cohesion: 0.10
Nodes (10): altClassHex(), altRatingHex(), GetAltChars(), M:_Cell(), M:RefreshAlts(), M:RefreshGear(), M:RefreshStats(), MakeSlotButton() (+2 more)

### Community 28 - "Community 28"
Cohesion: 0.18
Nodes (5): AS(), hasAS(), M:RefreshAlertes(), M:RefreshPerf(), M:RefreshTop()

## Knowledge Gaps
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `BagsOptions()` connect `Community 4` to `Community 12`?**
  _High betweenness centrality (0.003) - this node is a cross-community bridge._
- **Why does `Apply()` connect `Community 12` to `Community 4`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.09230769230769231 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.09538461538461539 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.06386554621848739 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.0846774193548387 - nodes in this community are weakly interconnected._
- **Should `Community 5` be split into smaller, more focused modules?**
  _Cohesion score 0.08923076923076922 - nodes in this community are weakly interconnected._