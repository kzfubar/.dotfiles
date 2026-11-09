---
name: kf-prose
description: Write a short chat message, text, DM, Discord reply, email or a few sentences of prose (Slack post, PR comment, doc paragraph) in Kevin's own voice by running `twin render` on the points he wants to make. He supplies the content; the tool only renders style. `/kf-prose build` first settles the content with him in chat. Not for long documents.
disable-model-invocation: true
---

# kf-prose

`twin render` turns a list of points into a message the way Kevin writes it: his casing, punctuation and habits at his real rates, worded after real
(points -> message) pairs from his history. It never decides what to say. Every point must come
from Kevin, and the tool checks that the output keeps each point and adds nothing.

The flow is: points (settled in chat for `build`), render 3 candidates, Kevin picks one, then
he edits it or keeps it. Picks and edits are recorded as feedback, which the renderer learns
from.

twin and its corpus live on the mini (`ssh mini`), the one canonical copy for every machine, so
picks and edits from anywhere train the same renderer. It runs there as the `aeris-claude`
user through `/opt/aeris/libexec/aeris-twin`, which takes the same arguments as `twin`. The
repo at `C:/Users/zkevi/projects/twin` is for developing twin; never render from it or from
`D:/chat-archive`, which are no longer updated.

Points go to the mini on stdin, one per line, so quotes and apostrophes survive SSH. Keep other
option values inside the single-quoted remote command simple (no apostrophes); send anything
else, such as a file, with the file pattern below.

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
printf '%s\n' "when should we meet at the station" \
  "i can get there any time after 2" \
  "when does your train arrive [question]" \
  | ssh mini 'sudo -u aeris-claude /opt/aeris/libexec/aeris-twin render --audience chat -n 3 --file /dev/stdin'
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
- `--draft FILE` instead of points when Kevin hands over a rough draft to restyle (send the
  file first; see "Files" below).
- Each render takes about 10-30 seconds and a cent or two per candidate. Always use `-n 3`.

stdout is only the message, one candidate per block (emails: separated by `---`). stderr has
the seed, the judge's verdict and the line `session <id>`; keep that id for section 3. If
stderr warns about a missed point or an invention, say so next to that candidate.

### Email

```
printf '%s\n' "my order arrived damaged" \
  "i'd like a replacement rather than a refund" \
  "can you send a return label [question]" \
  | ssh mini 'sudo -u aeris-claude /opt/aeris/libexec/aeris-twin render --audience email --register service --subject -n 3 --file /dev/stdin'
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
   ssh mini 'sudo -u aeris-claude /opt/aeris/libexec/aeris-twin feedback <session> --pick 2'
   ```

   For `none`, record `--pick none` and ask whether to re-render or change the points.
3. Kevin's next message is the follow-up, not another decision to ask for:
   - If he pastes an edited version, write it to a file in the scratchpad, send it to the mini
     (see "Files" below) and record it with `twin feedback <session> --final-file <path on the
     mini>`. Record exactly what he wrote.
   - If he says the pick is fine as is, record `twin feedback <session> --as-is`.
   - If he moves on without either, record nothing more. A missing final is fine.
4. Never send, post or schedule a message yourself.

`--explain` shows the sampled profile (habits, length, donor and pair ids). It never prints his
past messages; don't go looking for them in the pool files either. `twin feedback --stats`
summarizes the feedback so far.

## Files

`--draft`, `--reply-to` and `--final-file` take a path on the mini. Copy the file into
`aeris-claude`'s private folder (other users on the mini can't read it), use that path, and
delete it afterwards:

```
ssh mini 'sudo -u aeris-claude sh -c "umask 077; mkdir -p /var/db/aeris-claude/tmp; cat > /var/db/aeris-claude/tmp/reply.txt"' < reply.txt
ssh mini 'sudo -u aeris-claude /opt/aeris/libexec/aeris-twin render --audience email --reply-to /var/db/aeris-claude/tmp/reply.txt -n 3 --file /dev/stdin' < points.txt
ssh mini 'sudo -u aeris-claude rm -f /var/db/aeris-claude/tmp/reply.txt'
```

## If it fails

- It needs the mini reachable as `ssh mini` (Tailscale). On the mini, the corpus is in
  `/var/db/aeris-claude/twin-data` and twin calls Claude on Kevin's subscription through a
  token; `{"status":"no-token"}` means that token is missing, so tell Kevin.
- If a pool is missing, the error says to run `--build-pool`; that is a one-time ~$5 job, so
  ask Kevin before running it.
- `core` and `--engine core` need all three pools (`render-pool/ai`, `discord`, `email`).
- Email also needs `identity.json` (his names), the register labels (`twin email registers`)
  and the email pool (`twin render --audience email --build-pool`, one-time ~$6; ask Kevin
  first). Don't send email through `--audience chat`.
