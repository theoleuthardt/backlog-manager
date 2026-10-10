# Accessibility and keyboard checklist (Flutter client)

What the Flutter client in `app/` does for keyboard users, screen readers, contrast, reduced motion and text size, how each point is checked, and what still needs a person with the real platform tools. Update it when a screen changes.

## Checked by the test suite

| Area | Rule | Checked by |
| --- | --- | --- |
| Contrast | Foreground, secondary, muted and faint text have 4.5:1 on the background and on all three surfaces in every built-in theme; text on the accent colour and error text on a surface have 4.5:1; the accent stands out from the background with 3:1 | `test/design/contrast_test.dart` (the faint text of Shelf OLED, Light and Colorful and the derived faint tier were adjusted to pass; custom themes are the user's own colours and are not forced) |
| Keyboard | Every clickable part is a `ShelfPressable` (Tab reaches it, Enter and Space activate it, a 2 px accent ring shows the focus) or has its own focus handling: library games (`_EntryTarget`: Enter or Space opens, Delete asks to delete, arrows move), the segments of the interest and the stars (`_Adjustable`: arrow keys), check boxes, switches, menus | `test/design/widgets/pressable_test.dart`, `test/features/library/`, `test/features/accessibility/keyboard_test.dart` |
| Keyboard | Group headers of the library, theme items, the "Create it as a custom game" and "Show all achievements" links, and the rows of the CSV preview (cover, edit, duplicates) were mouse-only and are `ShelfPressable` now | `test/features/accessibility/keyboard_test.dart` and the tests of those screens |
| Semantics | Icon buttons need a tooltip (the constructor of `ShelfIconButton` requires it) which is their label; pressables with a `semanticLabel` announce it ("Playing, 12, expanded", "Shelf OLED, active", "Edit Neon") | `keyboard_test.dart`, `test/design/` |
| Text size | The app follows the text scale factor of the system; the main window does not overflow at 150 % | `keyboard_test.dart` ("text follows the text scale of the system") |
| Reduced motion | The slide of sheets, the animated switch and the sidebar transition are off when the system asks for less motion | `keyboard_test.dart`, `test/design/widgets/` |
| Esc and Enter | Esc closes a sheet or a menu, Enter saves in fields that save on Enter (names, secrets, the invitation field, the command palette), the inspector saves by itself | the tests of each screen |

## Needs a person (not automated)

These need the real screen readers and cannot run in CI. Run them on a beta build and tick them here.

- [ ] macOS VoiceOver: sign in, walk the sidebar, open a game in the library, change its status, add a game, open settings
- [ ] Windows Narrator: the same walk
- [ ] Linux Orca (Bazzite): the same walk
- [ ] High contrast mode of Windows: text stays readable
- [ ] 200 % text size on each platform: nothing is cut off on the library, the inspector and settings

## Known gaps

- Covers and rows of the library announce their title and hours but the context menu is only reachable with the mouse; the same actions are reachable from the selection bar and the inspector with the keyboard.
- The drag and drop between groups has no keyboard path; the status select of the inspector and "Move to" in the selection bar do the same.
- Custom themes can have colours with too little contrast; the theme creator does not warn about it.
