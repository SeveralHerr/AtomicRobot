# Per-platform posting (claude-in-chrome)

UIs drift: use `find` / `read_page` for refs by label, not stored coordinates. Upload with
`file_upload` on the `input[type=file]` ref (often hidden — `find "file input"` still finds it).
Fill text from `captions.json`. Screenshot before the final click.

## YouTube Shorts — studio.youtube.com/channel/UCmtDiOdYrY3estK6ZCr5DfQ
- Create (top right) → Upload videos → `file_upload` into the dialog's file input.
- Vertical + ≤3 min ⇒ auto-classed as a Short. Title = `youtube_title` (title box is
  contenteditable: select-all then type). Description = `youtube`.
- Audience: "No, it's not made for kids" (required radio). Next ×3 (Video elements, Checks —
  wait for "No issues found").
- Visibility: Public → Publish. Copy the shorts link from the done dialog.

## Bluesky — bsky.app
- New Post → paste `bluesky` text (links auto-detect; check the char counter ≤300).
- Media button's file input → `file_upload` the mp4 (≤3 min, ≤100 MB; first upload on an
  account may need email verification — if prompted, stop and tell the user).
- Video ALT → `bluesky_alt`. Wait for processing to finish, then Post.
- Link card: if a link-preview card for itch appears, remove it — video and card can't both attach.

## TikTok Studio — tiktok.com/tiktokstudio/upload
- `file_upload` into the upload area's input. Wait for the upload bar to finish.
- Description box (contenteditable) → clear the auto-filled filename, type `tiktok`. Hashtags
  typed with `#` open a suggestion popup — press Escape after each so it doesn't swap the tag.
- Cover: pick the hook frame. Who can watch: Everyone. Leave "AI-generated content" off (it isn't),
  leave "Content disclosure / branded" off unless the user says it's paid promo.
- Post. If a "Continue to post?" content-check dialog appears, report it before confirming.

## Instagram Reels — instagram.com
- Sidebar Create (+) → Post → "Select from computer" — don't click it; `find` the file input
  and `file_upload`. A "Video posts are now shared as reels" notice → OK.
- Crop: choose Original / 9:16 (portrait icon) so nothing is cut. Next → Next (skip filters).
- Caption = `instagram`. Optionally "Tag people"/collab with @atomicrobottattoo only if the user
  asked — a collab invite is a message on their behalf.
- Share. Copy the reel link from the profile.

## Common failures
- `file_upload` path rejected → file not shared with session; give user the path to drag in.
- >10 MB → re-encode lower bitrate (SKILL.md §2).
- Logged-out / wrong account → stop; user logs in (never type passwords).

## Learned 2026-10-05 (first real run)
- YouTube: Thumbnail > "Upload file" works for Shorts on desktop (9:16 PNG, <2 MB). Description links
  stay unclickable until the channel's one-time verification — tell the user. Account = channel name
  under the avatar in the left rail.
- Bluesky: own handle = `nav a[href^="/profile/"]` (feed links are other people's). The left-rail
  compose button moves with window size — click the "What's up?" box instead.
- Bluesky has NO file input until the media button is clicked (that opens a native picker). Working path:
  add a temp `<input type=file>` via JS, `file_upload` into it, then dispatch dragenter/dragover/drop
  with a DataTransfer of that file on `.ProseMirror` (paste is ignored). Remove the temp input after.
- Bluesky: Escape with no popup open CLOSES the composer and later keys fire page shortcuts (landed on
  search). End an @handle with a space instead of Escape. Remove the auto link card before the video.
- Brand tags: only mention an account you can tie to the brand (bio/link). `atomicrobot.bsky.social`
  has neither — not tagged. IG: Tag people @atomicrobottattoo is fine when the user asks for tags.
- Hidden window (`document.visibilityState == "hidden"`, MCP group window behind others): screenshots
  time out (`resize_window` revives them for one shot), and TikTok Studio + Instagram never start the
  upload — spinner forever, no network request, drop trick also ignored. Bluesky + YouTube still worked.
  Root cause: Chrome defers media loading in a never-shown tab (TikTok's own tutorial <video> sat at
  readyState 0). Fix = the user clicks the Claude tab-group window to front (confirmed: upload then
  worked first try); raising some other Chrome window does not help. Check visibilityState FIRST.
- TikTok Studio: after upload a "Turn on automatic content checks?" modal appears — Cancel (it is an
  account setting). Dismiss "New editing feature" with Got it. Mentions only count when picked from the
  suggestion list (shown bold); hashtags: Escape after each. Edit cover > Upload cover takes the PNG;
  check the 4:3 profile preview. Post lands "Content under review / Only me", then flips to Everyone.
  Captions ARE editable after posting (Posts > pencil > Save; triggers a short re-review).
- Instagram: "Video posts are now shared as reels" > OK. Crop defaults to 1:1 — crop icon (bottom-left)
  > Original. Edit step: Cover photo > "Select from computer" (hidden input, accept image/jpeg,png).
  Caption: end an @handle with a space before Enter. Tag people (on the preview) > search > pick by
  avatar. Share > "Your reel has been shared"; link from `/<user>/reels/` first `/reel/` href.
