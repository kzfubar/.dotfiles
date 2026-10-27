---
name: voice
description: Write a short chat message, text, DM, Discord reply or email in Kevin's own voice by running `twin render` on the points he wants to make, for a friend, co-worker, AI assistant or email recipient. He supplies the content; the tool only renders style. Not for long documents.
disable-model-invocation: true
---

# Voice

`twin render` (repo `C:/Users/zkevi/projects/twin`) turns a list of points into a message the
way Kevin writes it: his casing, punctuation and habits at his real rates, worded after real
(points -> message) pairs from his history. It never decides what to say. Every point must come
from Kevin, and the tool checks that the output keeps each point and adds nothing.

## 1. Turn the request into points

- One point per idea, in plain words, taken from what Kevin said. Don't add facts, reasons,
  greetings or offers he didn't give. If something needed is missing (a time, a name), ask him
  instead of filling it in.
- Phrase points the way the message should say them ("when should we meet at the station",
  not "figure out a meeting time"). The renderer stays close to the wording of the points.
- Flags mark content, not style. Add them only when the meaning calls for them:

  | flag | when |
  |---|---|
  | `[question]` | the point asks something |
  | `[tentative]` | he isn't sure ("probably", "i think") |
  | `[aside]` | a side remark, clarification or example |
  | `[joint]` | proposing to do something together |
  | `[shared]` | about shared work or a group he's in |

- Leave hedges and asides out of the point text itself; the flag carries them.

## 2. Run it

```
uv run --project C:/Users/zkevi/projects/twin twin render --audience friend -n 3 \
  --points "when should we meet at the station" \
  --points "i can get there any time after 2" \
  --points "when does your train arrive [question]"
```

- `--audience friend` for friends, co-workers, Discord and texts; `--audience ai` for messages
  to an AI assistant.
- `--intent ask|inform|react|request` if it's obvious; otherwise it's inferred from the points.
- `--draft FILE` instead of points when Kevin hands over a rough draft to restyle.
- Each render takes about 10-30 seconds and a cent or two; `-n 3` gives three candidates.

stdout is only the message, one candidate per block (emails: separated by `---`). stderr has the seed and the judge's
verdict. If stderr warns about a missed point or an invention, say so or re-render; don't patch
the wording by hand, since hand edits undo the style.

### Email

```
uv run --project C:/Users/zkevi/projects/twin twin render --audience email --register service   --subject -n 2   --points "my order arrived damaged"   --points "i'd like a replacement rather than a refund"   --points "can you send a return label [question]"
```

- `--register academic|career|colleague|service`: who it's to. If left out it's inferred, and
  stderr says so; check that it fits.
- `--to NAME` for a named greeting (otherwise "Hi," / "Hello,"); `--first-contact` when Kevin
  hasn't written to them before; `--reply-to FILE` with the email he's answering (anonymized
  before any model call, used only as context); `--subject` for a new email (stdout then starts
  with `Subject:`).
- Don't put a greeting, sign-off or pleasantries in the points; the tool adds those. A thanks
  or apology with real content is a point with its flag.
- Email flags, on top of the ones above:

  | flag | when |
  |---|---|
  | `[thanks]` | thanking them for something specific |
  | `[apology]` | apologizing for something specific |
  | `[attachment]` | something is attached |
  | `[agree]` | agreeing to what they proposed |
  | `[request]` | asking them to do something |
  | `[offer]` | offering help or more info (licenses "Let me know ...") |
  | `[upcoming]` | a future meeting or event (licenses "I look forward ...") |
  | `[item]` | one line of a list; two or more make a list |

- It writes his current (2023–25) email style, about 2 cents per candidate.

## 3. Hand it back

- Show the candidates as they came out, and let Kevin pick or ask for another round.
- Never send, post or schedule a message yourself.
- `--explain` shows the sampled profile (habits, length, donor and pair ids). It never prints
  his past messages; don't go looking for them in the pool files either.

## If it fails

- It needs `D:/chat-archive` (the store `twin.sqlite` and `twin/render-pool/`), `uv`, and the
  `claude` CLI on PATH. If the pool is missing, the error says to run `--build-pool`; that is a
  one-time ~$5 job, so ask Kevin before running it.
- Email also needs `D:/chat-archive/identity.json` (his names), the register labels
  (`twin email registers`) and the email pool (`twin render --audience email --build-pool`,
  one-time ~$6; ask Kevin first). Don't send email through `--audience friend`.
