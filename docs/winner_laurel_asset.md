# Winner laurel artwork

- Artwork: Golden Laurel Wreath, by GDJ (user-selected metallic broad leaves).
- Source: https://www.clipsafari.com/clips/o242637-golden-laurel-wreath
- License: CC0 1.0 / public domain, as stated on the source page.
- License reference: https://creativecommons.org/publicdomain/zero/1.0/
- Downloaded: 2026-10-08, unmodified PNG at
  `assets/images/winner_laurel.png`.
- Bundled using the existing Flutter `assets/images/` declaration. Displayed
  as an available artwork asset; no network request is needed at runtime.
- Updated 2026-10-08: replaced the previous narrow-leaf wreath and restored
  the first-place avatar area from 80 to 60 logical pixels, keeping the
  avatar and other podium dimensions unchanged.
- Removed from the podium on 2026-10-08 at the user's request. The PNG remains
  available in the repository; the podium no longer renders it or its backdrop.
- Code trial 2026-10-08: the podium now uses the user's Dart `LaurelAvatar`
  and `LaurelWreathPainter`, with gold leaves, brown outlines, a red ribbon
  and a finite growth animation. The 60px avatar area and 40px avatar are
  preserved. Compact podiums retain their plain avatars. Reduced motion
  disables the growth animation; changes to animation settings are supported.
- Rank style update 2026-10-08: applied the user's `LaurelStyle` revision,
  including gold/silver/bronze palettes, 7/6/5 leaves per branch and thinner
  outlines. All populated podium ranks now have wreaths, including compact
  layouts. Empty slots keep their placeholder avatars. Wreaths use the existing
  avatar padding so the podium box and avatar dimensions remain unchanged.
- Follow-up 2026-10-08: Home explicitly uses gold for top 1 and silver for
  top 2 and top 3. Top 3 also displays its silver wreath around the waiting
  placeholder when no third friend is available. Box dimensions are preserved.
- Final rank hierarchy 2026-10-08: Home uses the rank factory again: gold,
  silver, bronze for ranks 1–3. Each branch has 9, 6, 4 leaf pairs respectively
  so top 1 has the most detail and top 3 is simplest. The top 3 waiting slot
  retains its wreath, now bronze. Avatar and box sizes remain unchanged.
