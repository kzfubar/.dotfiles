---
name: voice
description: Write a short message in Kevin's own voice by running `twin render` on the points he wants to make. Use when Kevin asks to write, word, draft or reply to a chat message, text, DM or Discord message in his style, to a friend, co-worker or an AI assistant ("text them that...", "reply saying...", "write this like I would", "say this in my voice"). He supplies the content; the tool only renders style. Not for email (not supported yet) or for long documents.
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

stdout is only the message, one candidate per block. stderr has the seed and the judge's
verdict. If stderr warns about a missed point or an invention, say so or re-render; don't patch
the wording by hand, since hand edits undo the style.

## 3. Hand it back

- Show the candidates as they came out, and let Kevin pick or ask for another round.
- Never send, post or schedule a message yourself.
- `--explain` shows the sampled profile (habits, length, donor and pair ids). It never prints
  his past messages; don't go looking for them in the pool files either.

## If it fails

- It needs `D:/chat-archive` (the store `twin.sqlite` and `twin/render-pool/`), `uv`, and the
  `claude` CLI on PATH. If the pool is missing, the error says to run `--build-pool`; that is a
  one-time ~$5 job, so ask Kevin before running it.
- For email, say it isn't supported yet rather than forcing it through `--audience friend`.
