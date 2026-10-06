# Security

## Reporting

Use **GitHub's private vulnerability reporting** on this repository (Security
tab, "Report a vulnerability"). Please do not open a public issue for anything
that would expose someone's vehicle or credentials before it is fixed.

Say what you found, how to reproduce it, and what an attacker gets. You will
get an answer. This is a spare-time project by one person, so "promptly" means
days, not hours. If that is not fast enough for what you found, say so and I
will treat it accordingly.

There is no bounty. I will credit you in the release notes unless you prefer
otherwise.

## What the attack surface actually is

Worth knowing before you spend time looking.

**There is no server.** No backend, no proxy, no analytics, no telemetry, no
account system. Nothing this project runs receives your data, because there is
nothing to receive it. The path is watch → phone → Škoda, and the middle hop is
Garmin's own app, which Connect IQ requires: a watch app cannot open a socket
itself.

So the interesting surface is small: what the app stores on the watch, what it
sends, and what it does with a hostile response.

## Known and accepted

**The API key and S-PIN are stored unencrypted.** Connect IQ app settings are
not encrypted, and the platform offers no secure storage. Anyone with physical
access to an unlocked watch could read them. This is a property of Connect IQ,
not a choice this app makes, but users should know it: the
[privacy policy](docs/privacy-policy.md) says so plainly, and the app offers a
"Clear stored data" action.

Reports that amount to "settings are readable from the device" are accurate and
already documented. If you have found a way to make them *less* readable within
Connect IQ, that is a very welcome PR.

**A Škoda API key is scoped to vehicles the user picked** when creating it, and
expires after roughly 180 days with no refresh flow. A leaked key is bad but
bounded and revocable from the MyŠkoda app.

**The vehicle's parking position is cached on the watch** so it can be shown
without a network request. That is location data at rest on the device, cleared
by "Clear stored data" or uninstalling.

## Things genuinely worth reporting

- Anything that sends data anywhere other than the Škoda API host
- A way to make the app disclose the key or S-PIN over the wire, in a log, or
  on screen
- A malformed or hostile API response that crashes the app, or worse, causes it
  to act on attacker-controlled content
- Anything that causes a command to be sent without the user asking for it
- A path that spends the request quota without user action: the app is
  designed never to poll, and a violation of that is a real bug
- Weaknesses in `mock/`'s TLS setup that could affect a developer's machine

## Committed secrets

If you find a credential, key or real vehicle identifier committed to this
repository, report it privately rather than opening an issue.

`mock/tests/test_privacy.py` guards against this on every run: it fails on any
`msk_`-prefixed key, any unexplained high-precision coordinate, and any
street-address pattern in the fixture files. It exists because real data was
committed once already. If you find something it missed, that is a gap in the
guard as much as in the repository, and both should be fixed.
