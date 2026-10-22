# gform

Creates Google Forms from a JSON spec, each with a response Sheet linked to it. `Code.gs` is an
Apps Script web app that does the work inside a Google account; `gform` is the CLI that calls it.
The `google-forms` Claude skill (`claude-skills/google-forms`) covers the spec format and how
projects record and read their forms.

## Profiles

A web app runs as the account that deployed it, and that account owns every form and Sheet it
creates. Deploy `Code.gs` once per Google account that should own forms, and give each deployment
a profile in `gform.config.json` (gitignored):

| Field | Meaning |
|---|---|
| `url` | The deployment's web app URL, ending in `/exec` |
| `token` | Shared secret, also stored as the script's `TOKEN` property |
| `editors` | Emails added as editors on every form and Sheet this profile creates |
| `folder_id` | Drive folder the files are moved into; empty leaves them in My Drive |

`default` names the profile used without `--profile`. The token file is the one piece not in
the repo, so copy `gform.config.json` to a new machine by hand.

## Deploying a profile

1. Open https://script.google.com signed in as the owning account and create a new project.
   Name it `gform`.
2. Replace the contents of `Code.gs` with this directory's `Code.gs` and save.
3. Deploy > New deployment > type Web app. Set **Execute as: Me** and **Who has access: Anyone**,
   then Deploy and approve the permission screen. "Anyone" is needed for `curl` to reach it
   without a Google login; the token is what keeps others out.
4. Copy the web app URL and run `gform setup NAME URL`. It saves the profile and puts the token
   on the clipboard.
5. In the script's Project Settings > Script properties, add `TOKEN` with the clipboard value.
6. `gform ping --profile NAME` should print the owning account.

## Updating the script

After changing `Code.gs`, paste it into each deployment's project, then Deploy > Manage
deployments > edit (pencil) > Version: New version > Deploy. Editing the existing deployment
keeps its URL; "New deployment" would make a new one, which needs `gform setup NAME URL` again.
