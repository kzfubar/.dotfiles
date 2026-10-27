---
name: kf-prose
description: Write a short chat message, text, DM, Discord reply, email or a few sentences of prose (Slack post, PR comment, doc paragraph) in Kevin's own voice by running `twin render` on the points he wants to make. He supplies the content; the tool only renders style. `/kf-prose build` first settles the content with him in chat. Not for long documents.
disable-model-invocation: true
---

# kf-prose

`twin render` (repo `C:/Users/zkevi/projects/twin`) turns a list of points into a message the
way Kevin writes it: his casing, punctuation and habits at his real rates, worded after real
(points -> message) pairs from his history. It never decides what to say. Every point must come
from Kevin, and the tool checks that the output keeps each point and adds nothing.

The flow is: points (settled in chat for `build`), render 3 candidates, Kevin picks one, then
he edits it or keeps it. Picks and edits are recorded as feedback, which the renderer learns
from.

## 0. `build`: settle the content first

When invoked as `/kf-prose build`, or when Kevin describes a situation rather than what to say,
iterate with him in chat before rendering:

- Ask what the message has to get across and what he wants from it (an answer, a decision, a
  favor, just informing). Settle the audience and, for email, the register and recipient.
- Propose the point list (section 1's format, flags included) and revise it with him until he
  says it's right. Points are plain and unstyled here; don't draft the message itself, since
  the renderer does the wording.
- Don't add content he hasn't agreed to. Offer missing pieces as questions ("do you want to
  say when you're free?"), not as points.

Then render (section 2) with the settled points.

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

## 2. Render

```
uv run --project C:/Users/zkevi/projects/twin twin render --audience chat -n 3 \
  --points "when should we meet at the station" \
  --points "i can get there any time after 2" \
  --points "when does your train arrive [question]"
```

Audiences:

| `--audience` | for |
|---|---|
| `work` | AI assistants and co-workers |
| `chat` | friends, Discord, texts |
| `email` | email (see below) |
| `core` | a few capitalized, punctuated sentences for a Slack post, PR comment or doc paragraph |

(`ai`, `friend` and `prose` are old names for `work`, `chat` and `core`.)

- `--intent ask|inform|react|request` for chat if it's obvious; otherwise it's inferred.
- `--draft FILE` instead of points when Kevin hands over a rough draft to restyle.
- Each render takes about 10-30 seconds and a cent or two per candidate. Always use `-n 3`.

stdout is only the message, one candidate per block (emails: separated by `---`). stderr has
the seed, the judge's verdict and the line `session <id>`; keep that id for section 3. If
stderr warns about a missed point or an invention, say so next to that candidate.

### Email

```
uv run --project C:/Users/zkevi/projects/twin twin render --audience email --register service \
  --subject -n 3 \
  --points "my order arrived damaged" \
  --points "i'd like a replacement rather than a refund" \
  --points "can you send a return label [question]"
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

- It writes his current (2023-25) email style.

`--engine core` (with `--pool chat,discord,email`) also exists for work, chat and email, but the
default engine tested as well or better, so use the default.

## 3. Pick, then edit or keep

1. Show the candidates numbered 1-3, exactly as they came out. Don't fix the wording yourself;
   hand edits by you undo the style.
2. Ask which one with AskUserQuestion: options `1`, `2`, `3`, `none`. Record it right away:

   ```
   uv run --project C:/Users/zkevi/projects/twin twin feedback <session> --pick 2
   ```

   For `none`, record `--pick none` and ask whether to re-render or change the points.
3. Kevin's next message is the follow-up, not another decision to ask for:
   - If he pastes an edited version, write it to a file in the scratchpad and record it with
     `twin feedback <session> --final-file <file>`. Record exactly what he wrote.
   - If he says the pick is fine as is, record `twin feedback <session> --as-is`.
   - If he moves on without either, record nothing more. A missing final is fine.
4. Never send, post or schedule a message yourself.

`--explain` shows the sampled profile (habits, length, donor and pair ids). It never prints his
past messages; don't go looking for them in the pool files either. `twin feedback --stats`
summarizes the feedback so far.

## If it fails

- It needs `D:/chat-archive` (the store `twin.sqlite` and `twin/render-pool/`), `uv`, and the
  `claude` CLI on PATH, so it runs only where Claude Code runs on Kevin's machine. If a pool is
  missing, the error says to run `--build-pool`; that is a one-time ~$5 job, so ask Kevin
  before running it.
- `core` and `--engine core` need all three pools (`render-pool/ai`, `discord`, `email`).
- Email also needs `D:/chat-archive/identity.json` (his names), the register labels
  (`twin email registers`) and the email pool (`twin render --audience email --build-pool`,
  one-time ~$6; ask Kevin first). Don't send email through `--audience chat`.
