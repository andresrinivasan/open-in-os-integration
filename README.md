# open-in-os-integration

A one-command, non-interactive installer for the [WebExtension.ORG native
client](https://github.com/andy-portmen/native-client), the native messaging host that the
[Open in …](https://webextension.org/listing/open-in.html) browser extensions need in order to
hand a URL off to another application.

## Why this exists

My setup looks like this:

- **Firefox** is my primary browser.
- Site-specific browsers (SSBs) for apps like Notion run in something lighter — currently
  **Microsoft Edge**.
- Inside an SSB I want to stay in the SSB as long as I'm on the app's own domain. The moment a
  link leaves that domain (a Google Doc linked from a Notion page, say), I want it to open in
  Firefox instead.

That last step is done by the **Open in Firefox** extension in Edge. The extension can't launch
another application on its own; it talks to a small Node.js "native messaging host"
(`com.add0n.node`) installed outside the browser, and that host does the actual launching.

The native client's own installer is an interactive download-and-run-a-shell-script affair. In
practice the integration has to be re-established every time Edge updates, so doing it by hand
gets old fast. `install-native-client.sh` reduces the whole thing to one command.

## Usage

```sh
./install-native-client.sh
```

## What the script does

1. Queries the GitHub API for the latest release of
   [`andy-portmen/native-client`](https://github.com/andy-portmen/native-client) (unauthenticated,
   so no token needed).
2. Picks the asset matching the current platform, `mac.zip` on macOS, `linux.zip` on Linux, and
   downloads it to a temporary directory that is cleaned up on exit.
3. Extracts the archive, finds the bundled `install.sh`, and runs it.

Everything happens under `mktemp -d` and nothing is left behind.

## What the upstream installer does

Worth knowing, since this script is just a wrapper around it:

- If `node` (v6 or newer) is on your `PATH`, it uses it. Otherwise it downloads a pinned Node.js
  build (v18.20.5 as of native-client v1.1.2) to a temp directory and bundles a copy of the binary
  with the host.
- Installs the host itself into `~/.config/com.add0n.node/` (`run.sh`, `host.js`, `messaging.js`,
  and possibly `node`).
- Writes a `com.add0n.node.json` native messaging manifest into the `NativeMessagingHosts`
  directory of every browser it knows about, under `~/Library/Application Support/` on macOS:
  Microsoft Edge, Chrome, Chromium, Brave, Vivaldi, Comet, plus Firefox, Waterfox, Tor Browser
  and Thunderbird.
- Each manifest lists the extension IDs allowed to talk to the host, which is why a new
  native-client release is sometimes needed to support a newly published extension.

To remove all of it, run the `uninstall.sh` that ships inside the release archive.

## Requirements

- macOS or Linux, `sh`
- `curl` or `wget`
- `unzip` (release assets are zips)
- `node` on `PATH` is optional; the upstream installer downloads its own if needed

## Exit codes

| Code | Meaning |
| ---- | ------- |
| 2 | Neither `curl` nor `wget` available |
| 3 | Latest release has no downloadable assets |
| 4 | Asset is a zip but `unzip` is missing |
| 5 | Archive format unrecognized and no extraction tool available |
| 6 | No `install.sh` found inside the archive |
| other | Whatever the upstream `install.sh` exited with |

## Related

- [Open in … extension listing](https://webextension.org/listing/open-in.html)
- [andy-portmen/native-client](https://github.com/andy-portmen/native-client)

## License

Public domain ([Unlicense](LICENSE)).
