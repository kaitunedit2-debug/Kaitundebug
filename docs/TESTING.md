# Studio validation checklist

The source and demo pass a Lua 5.4 syntax parse in the packaging environment. Roblox APIs and rendering cannot be executed in this environment, so use this checklist in Roblox Studio before a production release.

## Window and lifecycle

- [ ] Create the window from a client `LocalScript`.
- [ ] Drag with mouse and touch; verify the close and minimize controls remain clickable.
- [ ] Resize the Studio viewport and verify the window stays within the viewport.
- [ ] Minimize, restore, call `SetSize`, and minimize/restore again.
- [ ] Hide/show with the configured toggle key.
- [ ] Destroy the window and verify global input handlers stop affecting it.

## Glass and theme

- [ ] Compare `LiquidGlass = true` and `false`.
- [ ] Compare `Blur = true` and `false` in a 3D scene with visible background detail.
- [ ] Open two blurred windows, destroy one, and verify the other retains its blur.
- [ ] Close the final blurred window and verify the AeroUI blur effect is removed.
- [ ] Switch Midnight, Light and Azure while a toggle is both on and off.
- [ ] Apply a custom accent and then switch themes.

## Controls

- [ ] Exercise button, toggle, slider, dropdown, input and keybind callbacks.
- [ ] Verify slider minimum, maximum and step rounding.
- [ ] Change dropdown options at runtime.
- [ ] Set controls programmatically with callbacks enabled and disabled.
- [ ] Verify notification timeout and manual close.

## Device and performance

- [ ] Test a narrow phone viewport and a desktop viewport.
- [ ] Test touch interactions on an actual device or Studio device emulator.
- [ ] Check that optional blur is acceptable on the target device class.
