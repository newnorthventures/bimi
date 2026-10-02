# New North Ventures — BIMI assets

This repository exists for one reason: to serve the New North Ventures BIMI mark from a
URL that New North Ventures controls permanently.

**Live URL:** `https://bimi.newnorthvc.com/logo.svg`

It is published with GitHub Pages and served over HTTPS at a custom subdomain. That URL goes
into the `l=` tag of the `default._bimi.newnorthvc.com` DNS record, and mailbox providers
fetch it directly to draw the sender logo in the inbox.

---

## Do not modify logo.svg

The certificate authority validates the file as it is served here, and a Common Mark
Certificate is granted on the basis of the mark as publicly used. Any edit — including a
"harmless" reformat, minify, or re-export from a design tool — can invalidate the
certificate and silently remove the logo from recipients' inboxes.

Treat this file as frozen artwork, not as source.

| | |
|---|---|
| Size | 1,676 bytes |
| SHA-256 | `e75d249117052798183d73a39f3b69d5810ad56a73cf5022010fd1e0009d1806` |
| MD5 | `ea5c3cd1c2cbf912bf269915287ddbcb` |

Verify at any time:

```sh
curl -s https://bimi.newnorthvc.com/logo.svg | sha256sum
# must print e75d249117052798183d73a39f3b69d5810ad56a73cf5022010fd1e0009d1806
```

The hexagon-N path inside the file hashes to
`b80dae5bd160405279009d9a0c9ef37d8ffa481bc0ceb47a07ce37837db0de98`. Every approved variant of
the mark carries that same path. If it ever differs, the artwork has drifted from what the
certificate covers.

---

## What the file is

An SVG conforming to the **SVG Tiny Portable/Secure (Tiny P/S)** profile, which BIMI requires.
In practice that means a deliberately restricted subset of SVG:

- `version="1.2"`, `baseProfile="tiny-ps"`
- a `<title>` element, present and first child
- a square `viewBox` (`0 0 512 512`)
- no `<script>`, `<a>`, `<image>`, `<use>`, `<foreignObject>`, animation or filters
- no external references, no embedded raster data, no event handlers

The mark reaches 84.1% of the circle radius, leaving 15.9% clearance so nothing clips when a
provider crops it to a circle.

---

## Why this repo instead of the website

Webflow serves uploaded assets only from its own CDN (`cdn.prod.website-files.com`) and
provides no way to map them onto a custom domain — a long-standing open feature request. CDN
URLs embed an asset ID, so rebuilding the site or migrating off Webflow silently changes the
URL and breaks BIMI.

Changing the `l=` URL afterwards means a DNS propagation window where some providers fetch the
old, dead URL and others the new one, so the indicator flickers or disappears. Hosting here
avoids that entirely.

---

## Requirements this URL has to keep meeting

Mailbox providers are unforgiving and fail silently. All four must hold:

| Requirement | Why it matters |
|---|---|
| HTTPS with a valid CA certificate | Self-signed or expired means silent rejection |
| `Content-Type: image/svg+xml` exactly | `text/plain` or `application/octet-stream` is rejected |
| Direct HTTP 200, **no 301/302** | Providers do not follow redirects |
| Under 32 KB | Currently 1,676 bytes |

Run `./verify.sh` (macOS/Linux/Git Bash) or `.\verify.ps1` (Windows PowerShell) to check all
four against the live URL.

---

## Windows: line endings will corrupt this file if you let them

Git for Windows ships with `core.autocrlf=true`, which rewrites LF to CRLF on checkout.
`logo.svg` contains 6 LF bytes, so that conversion turns a 1,676-byte file into a 1,682-byte
file with a completely different SHA-256 — invalidating the certified artwork and silently
killing the inbox logo.

`.gitattributes` in this repo prevents it (`* -text`, `logo.svg binary`). Do not remove it.
If you ever see **1,682 bytes**, that is exactly what happened:

```powershell
git config --global core.autocrlf input
```

then re-clone or re-extract. `.\verify.ps1` checks the local file for this before you push.

---

## Adding the certificate later

Once the Common Mark Certificate is issued it also needs a public HTTPS home, referenced by
the `a=` tag of the same DNS record. Commit it here as `cert.pem` and the record becomes:

```
default._bimi.newnorthvc.com.  TXT  "v=BIMI1; l=https://bimi.newnorthvc.com/logo.svg; a=https://bimi.newnorthvc.com/cert.pem"
```

One caveat to check rather than assume: confirm GitHub Pages serves `.pem` with a content type
the validators accept before relying on it. If it does not, rename it `cert.pem.txt` or host
the PEM elsewhere.

---

## Repository contents

```
CNAME          bimi.newnorthvc.com — tells GitHub Pages which custom domain to answer on
.nojekyll      disables Jekyll processing; files are served exactly as committed
.gitattributes blocks line-ending conversion — protects logo.svg byte-for-byte
logo.svg       the frozen BIMI mark
index.html     a plain landing page so the root is not a 404
verify.sh      post-deploy checks (macOS / Linux / Git Bash)
verify.ps1     the same checks for Windows PowerShell, plus a local pre-push check
```
