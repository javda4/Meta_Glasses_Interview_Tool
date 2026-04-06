-- ============================================================
-- RayBan Memory App — Supabase Database Setup
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. Enable the UUID extension (already enabled on most projects)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Create the memories table
CREATE TABLE IF NOT EXISTS public.memories (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    raw_transcript     TEXT         NOT NULL,
    structured_summary TEXT         NOT NULL,
    tags               TEXT[]       NOT NULL DEFAULT '{}',
    duration_seconds   FLOAT        NOT NULL DEFAULT 0,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 3. Index on created_at for fast ordered fetches
CREATE INDEX IF NOT EXISTS memories_created_at_idx ON public.memories (created_at DESC);

-- 4. Enable Row-Level Security
ALTER TABLE public.memories ENABLE ROW LEVEL SECURITY;

-- 5. Policies — adjust to match your auth strategy
--    Option A: Allow anon key (no auth required, good for dev / single-user)
CREATE POLICY "Allow anon select"
    ON public.memories FOR SELECT
    USING (true);

CREATE POLICY "Allow anon insert"
    ON public.memories FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow anon delete"
    ON public.memories FOR DELETE
    USING (true);

--    Option B: Restrict to authenticated users only (recommended for production)
--    Uncomment the block below and remove the anon policies above.
--
-- CREATE POLICY "Users can view own memories"
--     ON public.memories FOR SELECT
--     USING (auth.uid() = user_id);
--
-- CREATE POLICY "Users can insert own memories"
--     ON public.memories FOR INSERT
--     WITH CHECK (auth.uid() = user_id);
--
-- CREATE POLICY "Users can delete own memories"
--     ON public.memories FOR DELETE
--     USING (auth.uid() = user_id);
--
-- NOTE: If using Option B, add a `user_id UUID REFERENCES auth.users(id)` column
-- to the table and set it on insert.

-- 6. Verify
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'memories'
ORDER BY ordinal_position;
