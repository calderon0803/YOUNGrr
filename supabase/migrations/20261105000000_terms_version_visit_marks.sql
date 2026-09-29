-- New version of the privacy policy: it now explains the visit marks (see
-- 20261104000000_visit_marks.sql). Must match LEGAL.version in
-- src/config/app.js; everyone accepts it again on their next sign in.
create or replace function yg_terms_version() returns text
language sql immutable as $$ select '2026-09-29.2'::text $$;
