<!-- macbox:start -->
## iOS builds, tests, and the simulator: macbox

This project builds, tests, and runs on a remote Mac through macbox
(https://api.macbox.build/guide/). Use the macbox CLI, or its MCP tools, for any
xcodebuild, test, or simulator work, even when this machine can't run Xcode.

- `macbox build`, `macbox test`: exit 0 worked, 1 fix the code, 3 macbox's side (tell the user).
- `macbox run` launches the app and prints a live link: give it to the user. Then
  `macbox ui describe` and `macbox ui tap --id X` to check it works; `macbox stop` ends it.
- Not installed: `curl -fsSL https://api.macbox.build/install.sh | sh`, then `macbox status`.
  The key comes from MACBOX_API_KEY or `macbox login`; never ask for it in chat.
<!-- macbox:end -->
