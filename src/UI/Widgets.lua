local _, PC = ...

PC.Widgets = PeaversCommons.Widgets

-- The shared design system, aliased once here so that no panel has to reach
-- through _G for it.
--
-- It arrived in PeaversCommons 1.1.56. The TOC dependency guarantees load order
-- but not version, and CurseForge does not force a dependency upgrade, so the
-- one way this is nil is a player running an older PeaversCommons alongside a
-- newer PeaversConfig.
PC.Style = PeaversCommons.Style
