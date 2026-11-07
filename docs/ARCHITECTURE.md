# Architecture notes

## Reference review

The supplied WindUI archive organizes its implementation around a creation utility, a window system, tab/section components, individual elements, theme data, notifications and an Acrylic utility. That separation makes it easier to reason about the library than one large example script.

Its Acrylic implementation is more involved than a transparent `Frame`: the reviewed source combines a `DepthOfFieldEffect`, a camera-relative glass `Part`, a glass material, a painted UI surface and subtle texture layers. The camera-relative geometry is updated as the viewport and camera change. This is a useful reminder that “glass” is a stack of visual and rendering techniques, not one color value.

## AeroUI design decisions

AeroUI takes the following independent approach:

1. **Small public surface.** `CreateWindow`, `Window:Tab`, `Tab:Section` and the section control methods are the primary API.
2. **Theme tokens.** UI instances register the theme token that drives their color. `Window:SetTheme` updates those registered instances instead of rebuilding the window.
3. **Shared helpers.** Instance creation, corner treatment, strokes, text, tweening, callback isolation and blur ownership use a small set of local helpers.
4. **Native client APIs.** The library uses `Players.LocalPlayer`, `PlayerGui`, `UserInputService`, `TweenService` and `Lighting`. It avoids hidden CoreGui parents and executor-only helpers.
5. **Honest blur behavior.** `BlurEffect` applies to the 3D scene globally. The glass frame itself is styled with translucent layers, a gradient and edge highlights. There is no claim that a standard Roblox `Frame` can selectively blur only the pixels behind itself.
6. **Lifecycle.** Global connections are tracked per window. `Destroy` disconnects them and releases the shared blur effect when the final window closes.

## Current scope

This release intentionally focuses on the core window and common controls. It does not yet include persistence/config serialization, remote icon catalogs, key systems, code editors, viewport previews, multi-window docking or a plugin registry. Those features should be added as separate modules with tests and documented lifecycle rules rather than expanding the core API indiscriminately.
