## FitQuest build targets
## Run from repo root.

# ── Release APK (obfuscated) ─────────────────────────────────────────────────
# Symbol maps written to app/build/debug-info/ — keep them locally to decode
# crash stack traces. They are git-ignored and must NOT be committed.
apk:
	cd app && flutter build apk --release \
		--obfuscate \
		--split-debug-info=build/debug-info

# ── Release App Bundle for Play Store (obfuscated) ───────────────────────────
aab:
	cd app && flutter build appbundle --release \
		--obfuscate \
		--split-debug-info=build/debug-info

# ── Web build ────────────────────────────────────────────────────────────────
web:
	cd app && flutter build web --release

# ── Run on Chrome (dev) ──────────────────────────────────────────────────────
dev:
	cd app && flutter run -d chrome

# ── Backend: start local dev server ──────────────────────────────────────────
backend:
	cd backend && node src/index.js

.PHONY: apk aab web dev backend
