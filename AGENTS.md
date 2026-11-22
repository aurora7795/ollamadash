# Working on Ollama Dash

A native Qt 6 / Qt Quick dashboard for an Ollama server, built the way Omarchy's own apps are (one window, one job, keyboard first, follows the desktop theme). The binary, package, `.desktop` file and Wayland app id are all `ollamadash`.

## Commands

```sh
bin/build      # qmake6 + make into build/ollamadash
bin/test       # builds and runs the Qt Test binary offscreen (15 tests)
bin/install    # builds the package and runs makepkg -fsi
bin/screenshot # regenerates docs/screenshot.png from a fake Ollama (about 2 minutes)
```

No CMake. `src/` is flat. `build/`, `pkgbuild/pkg/`, `pkgbuild/src/` and `*.pkg.tar.*` are ignored.

## Layout

- `src/backend.{h,cpp}`: all state and network work as one `QObject`. Polls `/api/ps` every 2 s, and `/api/tags` and `/api/version` every 5th poll. The parsers are static functions so tests can call them with canned JSON.
- `src/Main.qml`: the window, layout and key bindings only. `HostDialog.qml`, `ModelDialog.qml`, `Panel.qml`, `RunningCard.qml`, `InstalledRow.qml` and `Sparkline.qml` are components.
- `src/theme.*`, `src/translator.*`: copied from Omarchy's apps (Omacut and Monologue). Keep them as they are.
- `src/i18n/*.json`: English text to translation. `en.json` holds only the plural.
- `tests/ollamadash_tests.cpp`: unit tests. They include `../src/*.cpp` directly and never touch the network.
- `tests/tools/`: the fake Ollama and the screenshot tool (not tests).

## Things that will bite you

- **The version lives in two places**: `VERSION` in `ollamadash.pro` and `pkgver` in `pkgbuild/PKGBUILD`. Bump both. `bin/build` deletes `main.o` (and `bin/screenshot` deletes `screenshot.o`) on purpose, because the version is a compile-time define and `make` does not notice `.pro` changes. Without that, a release ships the old number.
- **The saved host beats `$OLLAMA_HOST`.** Order: argument, saved setting (`~/.config/ollamadash/ollamadash.conf`), `$OLLAMA_HOST`, `127.0.0.1:11434`. When testing against a fake server, set `XDG_CONFIG_HOME` to a temp directory, or you will hit the user's real server and may capture it in a screenshot.
- **Never touch Omarchy's config**, and never run `omarchy language` to test translations. Point the `Translator` at a temporary language file instead.
- **Languages: only ones Omarchy supports.** Currently `es-MX`, `it` and `hu`. Omarchy has no plain `es` and no `gl`. `bin/test` checks that every catalog has the same keys and keeps the `%1` placeholders. New user-visible strings need adding to all three catalogs and to the `.desktop` `Comment` lines.
- **Layouts:** nested QML layouts default `fillWidth` to true. The right-hand System column sets `Layout.fillWidth: false` and a fixed width for that reason.
- **Offscreen screenshots** draw a cursor image if `cursorShape` is set, which shows up as a grey blob. It is not a UI bug.
- **Stale replies:** `m_generation` and `m_detailRequest` drop network replies that arrive after the host or model changed. Keep that when adding requests.
- **No tokens/s.** Ollama does not report it outside a request. Do not add a throughput graph without a proxy that reads `eval_count` and `eval_duration` from the final `/api/generate` or `/api/chat` chunk.

## Looking at the UI

`tests/tools/` has what you need to see the real QML without touching the desktop or a real server:

- `fake_ollama.py [port]` is a fake Ollama (`/api/ps`, `/api/tags`, `/api/version`, `POST /api/show`) with made-up models.
- `screenshot.cpp` loads `qrc:/Main.qml` offscreen (English, default accent `#FFD60A`, whatever this machine uses) and saves `grabWindow()` after a delay.
- `bin/screenshot [out.png] [delay-ms]` builds the tool, starts the fake server, runs it with an empty `XDG_CONFIG_HOME` and `OLLAMA_HOST` pointing at the fake, and writes `docs/screenshot.png`. The sparklines hold 60 samples at 2 s, so the default delay is 125 s. Use a short delay when you only want to look at a layout.

To test interaction, copy `screenshot.cpp` somewhere outside the repo and add `QTest::mouseClick` / `keyClick` calls on the window (link `testlib`). Set `QT_FORCE_STDERR_LOGGING=1` or QML warnings go to the journal.

The README screenshot must stay made-up and use a loopback host.

## Releasing

1. Bump the version in both places, run `bin/build` and check `strings -e l build/ollamadash | grep -x '0\.1\.[0-9]'` shows the new number.
2. Commit, push, then `gh release create vX.Y.Z --target <commit>`. Let GitHub create the tag; a local annotated tag would record the committer's identity.
3. For the AUR, `pkgbuild/aur/` holds a PKGBUILD that builds from the GitHub release tarball (the one in `pkgbuild/` builds the local tree). After each release: set `pkgver`, run `updpkgsums`, `makepkg --printsrcinfo > .SRCINFO`, test with `makepkg -f` in a temp copy, and add `install -Dm644 NOTICE …` once the tarball contains it (0.1.3 predates it).
4. Installing needs sudo and a terminal, so an agent cannot do it. Tell the user to run `bin/install` (or `makepkg -f` in `pkgbuild/` then `sudo pacman -U` the result).

## Git

Commit with the GitHub noreply identity, not the machine's git config: `git -c user.name=<login> -c user.email=<id>+<login>@users.noreply.github.com commit …`. Chain publish steps with `&&`, never newlines, so a failed push cannot lead on to the next step. Never force-push without checking what is on the remote first.
