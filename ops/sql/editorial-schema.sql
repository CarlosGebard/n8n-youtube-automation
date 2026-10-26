-- Editorial pipeline state. Apply this file to the separate `editorial` database,
-- never to n8n's internal schema.

CREATE TABLE IF NOT EXISTS articles (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  article_id TEXT NOT NULL UNIQUE,
  canonical_url TEXT NOT NULL UNIQUE,
  source TEXT NOT NULL,
  title TEXT NOT NULL,
  published_at_utc TIMESTAMPTZ,
  ingested_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  storage_provider TEXT NOT NULL DEFAULT 'nextcloud' CHECK (storage_provider = 'nextcloud'),
  content_uri TEXT,
  source_metadata_uri TEXT,
  content_fingerprint TEXT,
  content_bytes INTEGER,
  content_status TEXT NOT NULL DEFAULT 'pending_upload'
    CHECK (content_status IN ('pending_upload', 'stored', 'failed')),
  classification_status TEXT NOT NULL DEFAULT 'blocked'
    CHECK (classification_status IN ('blocked', 'pending', 'processing', 'classified', 'retry', 'failed')),
  classification_attempts INTEGER NOT NULL DEFAULT 0 CHECK (classification_attempts >= 0),
  classifier_lock_token TEXT,
  classifier_locked_at_utc TIMESTAMPTZ,
  classifier_last_error TEXT,
  decision TEXT CHECK (decision IN ('Individual', 'Queue', 'Discard')),
  topic TEXT,
  event_key TEXT,
  score INTEGER CHECK (score BETWEEN 0 AND 100),
  score_breakdown JSONB,
  reason TEXT,
  quality_flags JSONB,
  key_facts JSONB,
  factual_caveats JSONB,
  processed_at_utc TIMESTAMPTZ,
  expires_at_utc TIMESTAMPTZ,
  legacy_document_id TEXT,
  legacy_document_url TEXT
);

CREATE TABLE IF NOT EXISTS article_classifications (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  article_id BIGINT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  run_id TEXT,
  prompt_version TEXT NOT NULL,
  model TEXT NOT NULL,
  decision TEXT NOT NULL CHECK (decision IN ('Individual', 'Queue', 'Discard')),
  topic TEXT NOT NULL,
  event_key TEXT NOT NULL,
  score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
  score_breakdown JSONB NOT NULL,
  reason TEXT NOT NULL,
  quality_flags JSONB NOT NULL,
  key_facts JSONB NOT NULL,
  factual_caveats JSONB NOT NULL,
  raw_response JSONB NOT NULL,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Stage-owned state. The legacy storage and classification columns on articles
-- remain during the migration, but new workflows write to these tables.
CREATE TABLE IF NOT EXISTS article_contents (
  article_id BIGINT PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
  storage_provider TEXT NOT NULL DEFAULT 'nextcloud'
    CHECK (storage_provider = 'nextcloud'),
  markdown_uri TEXT NOT NULL,
  -- Metadata is embedded in the Markdown artifact. Historical JSON sidecars
  -- remain referenced here until a separately authorized retention cleanup.
  metadata_uri TEXT,
  -- PostgreSQL is the transport between ingestion and classification. Nextcloud
  -- remains the human-review artifact, not a required runtime dependency.
  markdown_content TEXT,
  content_fingerprint TEXT NOT NULL,
  content_bytes INTEGER NOT NULL CHECK (content_bytes >= 0),
  status TEXT NOT NULL CHECK (status IN ('pending_upload', 'stored', 'failed')),
  stored_at_utc TIMESTAMPTZ,
  last_error TEXT,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Existing installations created article_contents with a required JSON sidecar.
-- Keep those historical URIs, while allowing Markdown-only articles going
-- forward. DROP NOT NULL is idempotent.
ALTER TABLE article_contents ALTER COLUMN metadata_uri DROP NOT NULL;
ALTER TABLE article_contents ADD COLUMN IF NOT EXISTS markdown_content TEXT;

CREATE TABLE IF NOT EXISTS article_classification_jobs (
  article_id BIGINT PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'blocked'
    CHECK (status IN ('blocked', 'pending', 'processing', 'classified', 'retry', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  lock_token TEXT,
  locked_at_utc TIMESTAMPTZ,
  last_error TEXT,
  latest_classification_id BIGINT REFERENCES article_classifications(id) ON DELETE SET NULL,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  story_id TEXT NOT NULL UNIQUE,
  format TEXT NOT NULL CHECK (format IN ('Individual', 'Combined')),
  topic TEXT NOT NULL,
  editorial_angle TEXT,
  key_facts TEXT,
  factual_caveats TEXT,
  status TEXT NOT NULL DEFAULT 'Collecting',
  priority TEXT,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at_utc TIMESTAMPTZ,
  claimed_at_utc TIMESTAMPTZ,
  claimed_by TEXT,
  script_id TEXT,
  editorial_notes TEXT,
  assigned_video_id TEXT
);

CREATE TABLE IF NOT EXISTS story_articles (
  story_id BIGINT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  article_id BIGINT NOT NULL REFERENCES articles(id) ON DELETE RESTRICT,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (story_id, article_id)
);

CREATE TABLE IF NOT EXISTS daily_news_queues (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  queue_key TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  topic TEXT NOT NULL,
  editorial_angle TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'collecting'
    CHECK (status IN ('collecting', 'grouped', 'script_pending', 'scripted', 'voice_pending', 'video_pending', 'completed', 'failed')),
  ranking_prompt_version TEXT,
  ranking_model TEXT,
  ranking_response JSONB,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at_utc TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS daily_news_queue_articles (
  queue_id BIGINT NOT NULL REFERENCES daily_news_queues(id) ON DELETE CASCADE,
  article_id BIGINT NOT NULL REFERENCES articles(id) ON DELETE RESTRICT,
  classification_id BIGINT NOT NULL REFERENCES article_classifications(id) ON DELETE RESTRICT,
  rank INTEGER NOT NULL CHECK (rank > 0),
  included_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (queue_id, article_id),
  UNIQUE (article_id)
);

CREATE TABLE IF NOT EXISTS daily_news_scripts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  queue_id BIGINT NOT NULL UNIQUE REFERENCES daily_news_queues(id) ON DELETE CASCADE,
  prompt_version TEXT NOT NULL,
  model TEXT NOT NULL,
  script_text TEXT NOT NULL,
  script_uri TEXT,
  status TEXT NOT NULL DEFAULT 'ready'
    CHECK (status IN ('ready', 'voice_processing', 'voiced', 'video_processing', 'completed', 'failed')),
  raw_response JSONB NOT NULL,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_news_script_jobs (
  queue_id BIGINT PRIMARY KEY REFERENCES daily_news_queues(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'scripted', 'retry', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  lock_token TEXT,
  locked_at_utc TIMESTAMPTZ,
  last_error TEXT,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS individual_scripts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  article_id BIGINT NOT NULL UNIQUE REFERENCES articles(id) ON DELETE CASCADE,
  classification_id BIGINT NOT NULL REFERENCES article_classifications(id) ON DELETE RESTRICT,
  prompt_version TEXT NOT NULL,
  model TEXT NOT NULL,
  script_text TEXT NOT NULL,
  script_uri TEXT,
  status TEXT NOT NULL DEFAULT 'ready'
    CHECK (status IN ('ready', 'voice_processing', 'voiced', 'video_processing', 'completed', 'failed')),
  raw_response JSONB NOT NULL,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS individual_script_jobs (
  article_id BIGINT PRIMARY KEY REFERENCES articles(id) ON DELETE CASCADE,
  classification_id BIGINT NOT NULL REFERENCES article_classifications(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'scripted', 'retry', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  lock_token TEXT,
  locked_at_utc TIMESTAMPTZ,
  last_error TEXT,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Creative approval and production direction are independent stages. The
-- creative response remains immutable input to production; production output
-- cannot replace it.
ALTER TABLE daily_news_scripts
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS approved_at_utc TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS production_status TEXT NOT NULL DEFAULT 'blocked'
    CHECK (production_status IN ('blocked', 'pending', 'processing', 'ready', 'retry', 'failed')),
  ADD COLUMN IF NOT EXISTS production_prompt_version TEXT,
  ADD COLUMN IF NOT EXISTS production_model TEXT,
  ADD COLUMN IF NOT EXISTS production_response JSONB,
  ADD COLUMN IF NOT EXISTS production_uri TEXT;

ALTER TABLE individual_scripts
  ADD COLUMN IF NOT EXISTS approval_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS approved_at_utc TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS production_status TEXT NOT NULL DEFAULT 'blocked'
    CHECK (production_status IN ('blocked', 'pending', 'processing', 'ready', 'retry', 'failed')),
  ADD COLUMN IF NOT EXISTS production_prompt_version TEXT,
  ADD COLUMN IF NOT EXISTS production_model TEXT,
  ADD COLUMN IF NOT EXISTS production_response JSONB,
  ADD COLUMN IF NOT EXISTS production_uri TEXT;

CREATE TABLE IF NOT EXISTS voice_jobs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- `script_id` is the legacy Daily News reference.  It remains for backward
  -- compatibility while `individual_script_id` allows the same job contract
  -- to serve approved SINGLE_NEWS scripts.
  script_id BIGINT REFERENCES daily_news_scripts(id) ON DELETE CASCADE,
  individual_script_id BIGINT REFERENCES individual_scripts(id) ON DELETE CASCADE,
  script_type TEXT NOT NULL DEFAULT 'daily_news'
    CHECK (script_type IN ('daily_news', 'individual')),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  provider TEXT,
  model TEXT,
  voice_id TEXT,
  audio_uri TEXT,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  lock_token TEXT,
  locked_at_utc TIMESTAMPTZ,
  completed_at_utc TIMESTAMPTZ,
  last_error TEXT,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (script_type = 'daily_news' AND script_id IS NOT NULL AND individual_script_id IS NULL)
    OR
    (script_type = 'individual' AND script_id IS NULL AND individual_script_id IS NOT NULL)
  )
);

-- Upgrade installations created before Individual scripts reached voice.
ALTER TABLE voice_jobs
  ALTER COLUMN script_id DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS individual_script_id BIGINT
    REFERENCES individual_scripts(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS script_type TEXT NOT NULL DEFAULT 'daily_news'
    CHECK (script_type IN ('daily_news', 'individual')),
  ADD COLUMN IF NOT EXISTS model TEXT,
  ADD COLUMN IF NOT EXISTS attempts INTEGER NOT NULL DEFAULT 0
    CHECK (attempts >= 0),
  ADD COLUMN IF NOT EXISTS lock_token TEXT,
  ADD COLUMN IF NOT EXISTS locked_at_utc TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completed_at_utc TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'voice_jobs_script_source_check'
      AND conrelid = 'voice_jobs'::regclass
  ) THEN
    ALTER TABLE voice_jobs ADD CONSTRAINT voice_jobs_script_source_check CHECK (
      (script_type = 'daily_news' AND script_id IS NOT NULL AND individual_script_id IS NULL)
      OR
      (script_type = 'individual' AND script_id IS NULL AND individual_script_id IS NOT NULL)
    );
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS voice_jobs_daily_script_unique_idx
  ON voice_jobs (script_id) WHERE script_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS voice_jobs_individual_script_unique_idx
  ON voice_jobs (individual_script_id) WHERE individual_script_id IS NOT NULL;

-- Atomically creates (if necessary) and claims one approved production plan.
-- A completed job is never reclaimed, which makes audio generation idempotent.
CREATE OR REPLACE FUNCTION claim_editorial_voice_job(p_lock_token TEXT)
RETURNS TABLE (
  voice_job_id BIGINT,
  script_type TEXT,
  script_id BIGINT,
  script_text TEXT,
  production_response JSONB
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO voice_jobs (script_id, script_type)
  SELECT script.id, 'daily_news'
  FROM daily_news_scripts script
  WHERE script.approval_status = 'approved'
    AND script.production_status = 'ready'
    AND NOT EXISTS (
      SELECT 1 FROM voice_jobs job WHERE job.script_id = script.id
    )
  ON CONFLICT DO NOTHING;

  INSERT INTO voice_jobs (individual_script_id, script_type)
  SELECT script.id, 'individual'
  FROM individual_scripts script
  WHERE script.approval_status = 'approved'
    AND script.production_status = 'ready'
    AND NOT EXISTS (
      SELECT 1 FROM voice_jobs job WHERE job.individual_script_id = script.id
    )
  ON CONFLICT DO NOTHING;

  WITH candidate AS (
    SELECT job.id, job.script_type, job.script_id, job.individual_script_id
    FROM voice_jobs job
    LEFT JOIN daily_news_scripts daily ON daily.id = job.script_id
    LEFT JOIN individual_scripts individual ON individual.id = job.individual_script_id
    WHERE job.status IN ('pending', 'failed')
      AND job.attempts < 3
      AND (
        (job.script_type = 'daily_news' AND daily.approval_status = 'approved' AND daily.production_status = 'ready')
        OR
        (job.script_type = 'individual' AND individual.approval_status = 'approved' AND individual.production_status = 'ready')
      )
    ORDER BY job.updated_at_utc, job.id
    FOR UPDATE OF job SKIP LOCKED
    LIMIT 1
  )
  UPDATE voice_jobs job
  SET status = 'processing',
      attempts = job.attempts + 1,
      lock_token = p_lock_token,
      locked_at_utc = now(),
      last_error = NULL,
      updated_at_utc = now()
  FROM candidate
  WHERE job.id = candidate.id;

  UPDATE daily_news_scripts script
  SET status = 'voice_processing', updated_at_utc = now()
  WHERE script.id IN (
    SELECT job.script_id FROM voice_jobs job
    WHERE job.lock_token = p_lock_token AND job.status = 'processing'
  );

  UPDATE individual_scripts script
  SET status = 'voice_processing', updated_at_utc = now()
  WHERE script.id IN (
    SELECT job.individual_script_id FROM voice_jobs job
    WHERE job.lock_token = p_lock_token AND job.status = 'processing'
  );

  RETURN QUERY
  SELECT job.id,
         job.script_type,
         COALESCE(job.script_id, job.individual_script_id),
         COALESCE(daily.script_text, individual.script_text),
         COALESCE(daily.production_response, individual.production_response)
  FROM voice_jobs job
  LEFT JOIN daily_news_scripts daily ON daily.id = job.script_id
  LEFT JOIN individual_scripts individual ON individual.id = job.individual_script_id
  WHERE job.lock_token = p_lock_token AND job.status = 'processing';
END;
$$;

CREATE TABLE IF NOT EXISTS video_jobs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  script_id BIGINT NOT NULL REFERENCES daily_news_scripts(id) ON DELETE CASCADE,
  voice_job_id BIGINT REFERENCES voice_jobs(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  video_uri TEXT,
  last_error TEXT,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Word-level timing is a separate, retryable stage after a WAV exists.
CREATE TABLE IF NOT EXISTS audio_alignments (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  voice_job_id BIGINT NOT NULL UNIQUE REFERENCES voice_jobs(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  lock_token TEXT,
  locked_at_utc TIMESTAMPTZ,
  provider TEXT NOT NULL DEFAULT 'openai-whisper-1',
  alignment_uri TEXT,
  words JSONB,
  last_error TEXT,
  completed_at_utc TIMESTAMPTZ,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION claim_audio_alignment_job(p_lock_token TEXT, p_voice_job_id BIGINT DEFAULT NULL)
RETURNS TABLE (voice_job_id BIGINT, audio_uri TEXT, script_text TEXT)
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO audio_alignments (voice_job_id)
  SELECT voice.id FROM voice_jobs voice
  WHERE voice.status = 'completed' AND voice.audio_uri IS NOT NULL
    AND (p_voice_job_id IS NULL OR voice.id = p_voice_job_id)
  ON CONFLICT (voice_job_id) DO NOTHING;

  WITH candidate AS (
    SELECT alignment.id FROM audio_alignments alignment
    JOIN voice_jobs voice ON voice.id = alignment.voice_job_id
    WHERE alignment.status IN ('pending', 'failed') AND alignment.attempts < 3
      AND (p_voice_job_id IS NULL OR alignment.voice_job_id = p_voice_job_id)
    ORDER BY alignment.updated_at_utc, alignment.id FOR UPDATE SKIP LOCKED LIMIT 1
  )
  UPDATE audio_alignments alignment SET status='processing', attempts=attempts+1,
    lock_token=p_lock_token, locked_at_utc=now(), last_error=NULL, updated_at_utc=now()
  FROM candidate WHERE alignment.id=candidate.id;

  RETURN QUERY
  SELECT voice.id, voice.audio_uri,
    COALESCE(daily.script_text, individual.script_text)
  FROM audio_alignments alignment
  JOIN voice_jobs voice ON voice.id=alignment.voice_job_id
  LEFT JOIN daily_news_scripts daily ON daily.id=voice.script_id
  LEFT JOIN individual_scripts individual ON individual.id=voice.individual_script_id
  WHERE alignment.lock_token=p_lock_token AND alignment.status='processing';
END; $$;

CREATE TABLE IF NOT EXISTS pipeline_runs (
  run_id TEXT PRIMARY KEY,
  pipeline TEXT NOT NULL,
  started_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at_utc TIMESTAMPTZ,
  status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'failed')),
  scanned INTEGER NOT NULL DEFAULT 0,
  eligible INTEGER NOT NULL DEFAULT 0,
  expired INTEGER NOT NULL DEFAULT 0,
  ready_created INTEGER NOT NULL DEFAULT 0,
  error_count INTEGER NOT NULL DEFAULT 0,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS editorial_exports (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  export_name TEXT NOT NULL,
  content_uri TEXT NOT NULL,
  created_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  row_count INTEGER NOT NULL CHECK (row_count >= 0),
  run_id TEXT REFERENCES pipeline_runs(run_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS articles_classification_queue_idx
  ON articles (classification_status, content_status, published_at_utc)
  WHERE classification_status IN ('pending', 'retry') AND content_status = 'stored';

CREATE INDEX IF NOT EXISTS articles_event_key_idx ON articles (event_key) WHERE event_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS article_classifications_article_idx ON article_classifications (article_id, created_at_utc DESC);
CREATE INDEX IF NOT EXISTS article_classification_jobs_claim_idx
  ON article_classification_jobs (status, updated_at_utc)
  WHERE status IN ('pending', 'retry');
CREATE INDEX IF NOT EXISTS daily_news_queue_articles_classification_idx
  ON daily_news_queue_articles (classification_id);
CREATE INDEX IF NOT EXISTS daily_news_script_jobs_claim_idx
  ON daily_news_script_jobs (status, updated_at_utc)
  WHERE status IN ('pending', 'retry');
CREATE INDEX IF NOT EXISTS individual_script_jobs_claim_idx
  ON individual_script_jobs (status, updated_at_utc)
  WHERE status IN ('pending', 'retry');
CREATE INDEX IF NOT EXISTS daily_news_scripts_production_claim_idx
  ON daily_news_scripts (approval_status, production_status, updated_at_utc)
  WHERE approval_status = 'approved' AND production_status IN ('pending', 'retry');
CREATE INDEX IF NOT EXISTS individual_scripts_production_claim_idx
  ON individual_scripts (approval_status, production_status, updated_at_utc)
  WHERE approval_status = 'approved' AND production_status IN ('pending', 'retry');

-- Backfill stage tables from the original monolithic article state. This is
-- idempotent and deliberately leaves legacy columns untouched for rollback.
INSERT INTO article_contents (
  article_id, storage_provider, markdown_uri, metadata_uri, content_fingerprint,
  content_bytes, status, stored_at_utc, created_at_utc, updated_at_utc
)
SELECT
  id,
  storage_provider,
  content_uri,
  source_metadata_uri,
  COALESCE(content_fingerprint, md5(COALESCE(content_uri, article_id))),
  COALESCE(content_bytes, 0),
  content_status,
  CASE WHEN content_status = 'stored' THEN updated_at_utc END,
  ingested_at_utc,
  updated_at_utc
FROM articles
WHERE content_uri IS NOT NULL AND source_metadata_uri IS NOT NULL
ON CONFLICT (article_id) DO NOTHING;

INSERT INTO article_classification_jobs (
  article_id, status, attempts, lock_token, locked_at_utc, last_error,
  latest_classification_id, created_at_utc, updated_at_utc
)
SELECT
  a.id,
  CASE
    WHEN c.status <> 'stored' THEN 'blocked'
    WHEN a.classification_status = 'processing' THEN 'retry'
    ELSE a.classification_status
  END,
  a.classification_attempts,
  a.classifier_lock_token,
  a.classifier_locked_at_utc,
  a.classifier_last_error,
  latest.id,
  a.ingested_at_utc,
  a.updated_at_utc
FROM articles AS a
JOIN article_contents AS c ON c.article_id = a.id
LEFT JOIN LATERAL (
  SELECT id
  FROM article_classifications
  WHERE article_id = a.id
  ORDER BY created_at_utc DESC, id DESC
  LIMIT 1
) AS latest ON true
ON CONFLICT (article_id) DO NOTHING;

-- Existing Individual decisions predate individual_script_jobs. Seed one
-- runnable job from each latest immutable classification without changing the
-- classification history.
INSERT INTO individual_script_jobs (article_id, classification_id, status)
SELECT job.article_id, job.latest_classification_id, 'pending'
FROM article_classification_jobs AS job
JOIN article_classifications AS classification
  ON classification.id = job.latest_classification_id
WHERE job.status = 'classified'
  AND classification.decision = 'Individual'
ON CONFLICT (article_id) DO UPDATE
SET classification_id = EXCLUDED.classification_id,
    status = CASE
      WHEN individual_script_jobs.status = 'processing' THEN 'processing'
      ELSE individual_script_jobs.status
    END,
    updated_at_utc = now();

CREATE OR REPLACE FUNCTION claim_articles_for_classification(
  claim_token TEXT,
  claim_limit INTEGER
)
RETURNS TABLE (
  id BIGINT,
  article_id TEXT,
  title TEXT,
  source TEXT,
  canonical_url TEXT,
  published_at_utc TIMESTAMPTZ,
  content_uri TEXT
)
LANGUAGE sql
AS $$
  WITH candidates AS (
    SELECT a.id
    FROM articles AS a
    WHERE a.content_status = 'stored'
      AND a.classification_status IN ('pending', 'retry')
      AND (a.expires_at_utc IS NULL OR a.expires_at_utc > now())
    ORDER BY a.published_at_utc DESC NULLS LAST, a.id
    FOR UPDATE SKIP LOCKED
    LIMIT claim_limit
  ), claimed AS (
    UPDATE articles AS a
    SET classification_status = 'processing',
        classifier_lock_token = claim_token,
        classifier_locked_at_utc = now(),
        classification_attempts = a.classification_attempts + 1,
        updated_at_utc = now()
    FROM candidates AS c
    WHERE a.id = c.id
    RETURNING a.id, a.article_id, a.title, a.source, a.canonical_url,
              a.published_at_utc, a.content_uri
  )
  SELECT * FROM claimed;
$$;

-- PostgreSQL cannot alter a function's OUT-row shape in place. These two
-- functions are internal queue claims (not public APIs), so recreate them
-- before adding the Markdown payload to their result contract.
DROP FUNCTION IF EXISTS claim_article_classification_job(TEXT);
DROP FUNCTION IF EXISTS claim_article_classification_jobs(TEXT, INTEGER);

CREATE FUNCTION claim_article_classification_job(
  claim_token TEXT
)
RETURNS TABLE (
  id BIGINT,
  article_id TEXT,
  title TEXT,
  source TEXT,
  canonical_url TEXT,
  published_at_utc TIMESTAMPTZ,
  markdown_uri TEXT,
  markdown_content TEXT
)
LANGUAGE sql
AS $$
  WITH candidate AS (
    SELECT job.article_id
    FROM article_classification_jobs AS job
    JOIN article_contents AS content ON content.article_id = job.article_id
    JOIN articles AS article ON article.id = job.article_id
    WHERE content.status = 'stored'
      AND content.markdown_content IS NOT NULL
      AND job.status IN ('pending', 'retry')
      AND (article.expires_at_utc IS NULL OR article.expires_at_utc > now())
    ORDER BY article.published_at_utc DESC NULLS LAST, article.id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  ), claimed AS (
    UPDATE article_classification_jobs AS job
    SET status = 'processing',
        lock_token = claim_token,
        locked_at_utc = now(),
        attempts = job.attempts + 1,
        updated_at_utc = now()
    FROM candidate
    WHERE job.article_id = candidate.article_id
    RETURNING job.article_id
  )
  SELECT article.id, article.article_id, article.title, article.source,
         article.canonical_url, article.published_at_utc, content.markdown_uri,
         content.markdown_content
  FROM claimed
  JOIN articles AS article ON article.id = claimed.article_id
  JOIN article_contents AS content ON content.article_id = claimed.article_id;
$$;

CREATE FUNCTION claim_article_classification_jobs(
  claim_token TEXT,
  claim_limit INTEGER
)
RETURNS TABLE (
  id BIGINT,
  article_id TEXT,
  title TEXT,
  source TEXT,
  canonical_url TEXT,
  published_at_utc TIMESTAMPTZ,
  markdown_uri TEXT,
  markdown_content TEXT
)
LANGUAGE sql
AS $$
  WITH candidate AS (
    SELECT job.article_id
    FROM article_classification_jobs AS job
    JOIN article_contents AS content ON content.article_id = job.article_id
    JOIN articles AS article ON article.id = job.article_id
    WHERE content.status = 'stored'
      AND content.markdown_content IS NOT NULL
      AND job.status IN ('pending', 'retry')
      AND (article.expires_at_utc IS NULL OR article.expires_at_utc > now())
    ORDER BY article.published_at_utc DESC NULLS LAST, article.id
    FOR UPDATE SKIP LOCKED
    -- A NULL limit explicitly means "claim the complete eligible queue".
    -- Keep negative limits safe by treating them as zero.
    LIMIT CASE
      WHEN claim_limit IS NULL THEN NULL
      ELSE GREATEST(claim_limit, 0)
    END
  ), claimed AS (
    UPDATE article_classification_jobs AS job
    SET status = 'processing',
        lock_token = claim_token,
        locked_at_utc = now(),
        attempts = job.attempts + 1,
        updated_at_utc = now()
    FROM candidate
    WHERE job.article_id = candidate.article_id
    RETURNING job.article_id
  )
  SELECT article.id, article.article_id, article.title, article.source,
         article.canonical_url, article.published_at_utc, content.markdown_uri,
         content.markdown_content
  FROM claimed
  JOIN articles AS article ON article.id = claimed.article_id
  JOIN article_contents AS content ON content.article_id = claimed.article_id
  ORDER BY article.published_at_utc DESC NULLS LAST, article.id;
$$;

CREATE OR REPLACE FUNCTION claim_daily_news_script_job(
  claim_token TEXT
)
RETURNS TABLE (
  queue_id BIGINT,
  queue_key TEXT,
  title TEXT,
  topic TEXT,
  editorial_angle TEXT
)
LANGUAGE sql
AS $$
  WITH candidate AS (
    SELECT job.queue_id
    FROM daily_news_script_jobs AS job
    JOIN daily_news_queues AS queue ON queue.id = job.queue_id
    WHERE job.status IN ('pending', 'retry')
      AND queue.status = 'script_pending'
    ORDER BY queue.created_at_utc, queue.id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
  ), claimed AS (
    UPDATE daily_news_script_jobs AS job
    SET status = 'processing',
        lock_token = claim_token,
        locked_at_utc = now(),
        attempts = job.attempts + 1,
        updated_at_utc = now()
    FROM candidate
    WHERE job.queue_id = candidate.queue_id
    RETURNING job.queue_id
  )
  SELECT queue.id, queue.queue_key, queue.title, queue.topic, queue.editorial_angle
  FROM claimed
  JOIN daily_news_queues AS queue ON queue.id = claimed.queue_id;
$$;

-- A script may never be created from an article older than 72 hours since its
-- Dexerto publication.  Mark expired work terminally, rather than leaving it
-- pending for every later run to inspect again.
ALTER TABLE articles DROP CONSTRAINT IF EXISTS articles_classification_status_check;
ALTER TABLE articles ADD CONSTRAINT articles_classification_status_check
  CHECK (classification_status IN ('blocked', 'pending', 'processing', 'classified', 'retry', 'failed', 'expired'));

ALTER TABLE article_classification_jobs DROP CONSTRAINT IF EXISTS article_classification_jobs_status_check;
ALTER TABLE article_classification_jobs ADD CONSTRAINT article_classification_jobs_status_check
  CHECK (status IN ('blocked', 'pending', 'processing', 'classified', 'retry', 'failed', 'expired'));

ALTER TABLE individual_script_jobs DROP CONSTRAINT IF EXISTS individual_script_jobs_status_check;
ALTER TABLE individual_script_jobs ADD CONSTRAINT individual_script_jobs_status_check
  CHECK (status IN ('pending', 'processing', 'scripted', 'retry', 'failed', 'expired'));

ALTER TABLE daily_news_script_jobs DROP CONSTRAINT IF EXISTS daily_news_script_jobs_status_check;
ALTER TABLE daily_news_script_jobs ADD CONSTRAINT daily_news_script_jobs_status_check
  CHECK (status IN ('pending', 'processing', 'scripted', 'retry', 'failed', 'expired'));

ALTER TABLE daily_news_queues DROP CONSTRAINT IF EXISTS daily_news_queues_status_check;
ALTER TABLE daily_news_queues ADD CONSTRAINT daily_news_queues_status_check
  CHECK (status IN ('collecting', 'grouped', 'script_pending', 'scripted', 'voice_pending', 'video_pending', 'completed', 'failed', 'expired'));

CREATE OR REPLACE FUNCTION expire_editorial_script_jobs()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE articles AS article
  SET classification_status = 'expired',
      updated_at_utc = now()
  WHERE (
      article.published_at_utc IS NULL
      OR COALESCE(article.expires_at_utc, article.published_at_utc + interval '72 hours') <= now()
    )
    AND article.classification_status <> 'expired';

  UPDATE article_classification_jobs AS job
  SET status = 'expired',
      lock_token = NULL,
      locked_at_utc = NULL,
      last_error = 'Expired before script production (72-hour Dexerto limit).',
      updated_at_utc = now()
  FROM articles AS article
  WHERE article.id = job.article_id
    AND article.classification_status = 'expired'
    AND job.status IN ('pending', 'retry', 'classified');

  UPDATE individual_script_jobs AS job
  SET status = 'expired',
      lock_token = NULL,
      locked_at_utc = NULL,
      last_error = 'Expired before script production (72-hour Dexerto limit).',
      updated_at_utc = now()
  FROM articles AS article
  WHERE article.id = job.article_id
    AND article.classification_status = 'expired'
    AND job.status IN ('pending', 'retry');

  UPDATE daily_news_queues AS queue
  SET status = 'expired',
      updated_at_utc = now()
  WHERE queue.status IN ('collecting', 'grouped', 'script_pending')
    AND EXISTS (
      SELECT 1
      FROM daily_news_queue_articles AS membership
      JOIN articles AS article ON article.id = membership.article_id
      WHERE membership.queue_id = queue.id
        AND article.classification_status = 'expired'
    );

  UPDATE daily_news_script_jobs AS job
  SET status = 'expired',
      lock_token = NULL,
      locked_at_utc = NULL,
      last_error = 'Queue contains an article expired by the 72-hour Dexerto limit.',
      updated_at_utc = now()
  FROM daily_news_queues AS queue
  WHERE queue.id = job.queue_id
    AND queue.status = 'expired'
    AND job.status IN ('pending', 'retry');
END;
$$;

CREATE OR REPLACE FUNCTION claim_editorial_script_job(
  claim_token TEXT
)
RETURNS TABLE (
  job_type TEXT,
  subject_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM expire_editorial_script_jobs();

  RETURN QUERY
  WITH daily_candidate AS (
    SELECT 'daily'::TEXT AS job_type, job.queue_id AS subject_id,
           job.created_at_utc
    FROM daily_news_script_jobs AS job
    JOIN daily_news_queues AS queue ON queue.id = job.queue_id
    WHERE job.status IN ('pending', 'retry')
      AND queue.status = 'script_pending'
      AND NOT EXISTS (
        SELECT 1
        FROM daily_news_queue_articles AS membership
        JOIN articles AS article ON article.id = membership.article_id
        WHERE membership.queue_id = queue.id
          AND (
            article.published_at_utc IS NULL
            OR COALESCE(article.expires_at_utc, article.published_at_utc + interval '72 hours') <= now()
          )
      )
    ORDER BY job.created_at_utc, job.queue_id
    FOR UPDATE OF job SKIP LOCKED
    LIMIT 1
  ), individual_candidate AS (
    SELECT 'individual'::TEXT AS job_type, job.article_id AS subject_id,
           job.created_at_utc
    FROM individual_script_jobs AS job
    JOIN article_classification_jobs AS classification_job
      ON classification_job.article_id = job.article_id
    JOIN article_classifications AS classification
      ON classification.id = job.classification_id
    JOIN articles AS article ON article.id = job.article_id
    WHERE job.status IN ('pending', 'retry')
      AND classification_job.status = 'classified'
      AND classification.decision = 'Individual'
      AND article.published_at_utc IS NOT NULL
      AND COALESCE(article.expires_at_utc, article.published_at_utc + interval '72 hours') > now()
    ORDER BY job.created_at_utc, job.article_id
    FOR UPDATE OF job SKIP LOCKED
    LIMIT 1
  ), candidate AS (
    SELECT * FROM daily_candidate
    UNION ALL
    SELECT * FROM individual_candidate
    ORDER BY created_at_utc, subject_id
    LIMIT 1
  ), claimed_daily AS (
    UPDATE daily_news_script_jobs AS job
    SET status = 'processing', lock_token = claim_token, locked_at_utc = now(),
        attempts = job.attempts + 1, updated_at_utc = now()
    FROM candidate
    WHERE candidate.job_type = 'daily' AND job.queue_id = candidate.subject_id
    RETURNING job.queue_id
  ), claimed_individual AS (
    UPDATE individual_script_jobs AS job
    SET status = 'processing', lock_token = claim_token, locked_at_utc = now(),
        attempts = job.attempts + 1, updated_at_utc = now()
    FROM candidate
    WHERE candidate.job_type = 'individual' AND job.article_id = candidate.subject_id
    RETURNING job.article_id
  )
  SELECT 'daily'::TEXT, queue_id FROM claimed_daily
  UNION ALL
  SELECT 'individual'::TEXT, article_id FROM claimed_individual;
END;
$$;

-- Event-driven callers pass the exact job that they just created.  Manual
-- workflow 04 runs pass NULLs and retain the queue-draining behavior.
CREATE OR REPLACE FUNCTION claim_editorial_script_job(
  claim_token TEXT,
  requested_job_type TEXT,
  requested_subject_id BIGINT
)
RETURNS TABLE (
  job_type TEXT,
  subject_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM expire_editorial_script_jobs();

  RETURN QUERY
  WITH daily_candidate AS (
    SELECT 'daily'::TEXT AS job_type, job.queue_id AS subject_id,
           job.created_at_utc
    FROM daily_news_script_jobs AS job
    JOIN daily_news_queues AS queue ON queue.id = job.queue_id
    WHERE job.status IN ('pending', 'retry')
      AND queue.status = 'script_pending'
      AND (
        (requested_job_type IS NULL AND requested_subject_id IS NULL)
        OR (requested_job_type = 'daily' AND requested_subject_id = job.queue_id)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM daily_news_queue_articles AS membership
        JOIN articles AS article ON article.id = membership.article_id
        WHERE membership.queue_id = queue.id
          AND (
            article.published_at_utc IS NULL
            OR COALESCE(article.expires_at_utc, article.published_at_utc + interval '72 hours') <= now()
          )
      )
    ORDER BY job.created_at_utc, job.queue_id
    FOR UPDATE OF job SKIP LOCKED
    LIMIT 1
  ), individual_candidate AS (
    SELECT 'individual'::TEXT AS job_type, job.article_id AS subject_id,
           job.created_at_utc
    FROM individual_script_jobs AS job
    JOIN article_classification_jobs AS classification_job
      ON classification_job.article_id = job.article_id
    JOIN article_classifications AS classification
      ON classification.id = job.classification_id
    JOIN articles AS article ON article.id = job.article_id
    WHERE job.status IN ('pending', 'retry')
      AND classification_job.status = 'classified'
      AND classification.decision = 'Individual'
      AND article.published_at_utc IS NOT NULL
      AND COALESCE(article.expires_at_utc, article.published_at_utc + interval '72 hours') > now()
      AND (
        (requested_job_type IS NULL AND requested_subject_id IS NULL)
        OR (requested_job_type = 'individual' AND requested_subject_id = job.article_id)
      )
    ORDER BY job.created_at_utc, job.article_id
    FOR UPDATE OF job SKIP LOCKED
    LIMIT 1
  ), candidate AS (
    SELECT * FROM daily_candidate
    UNION ALL
    SELECT * FROM individual_candidate
    ORDER BY created_at_utc, subject_id
    LIMIT 1
  ), claimed_daily AS (
    UPDATE daily_news_script_jobs AS job
    SET status = 'processing', lock_token = claim_token, locked_at_utc = now(),
        attempts = job.attempts + 1, updated_at_utc = now()
    FROM candidate
    WHERE candidate.job_type = 'daily' AND job.queue_id = candidate.subject_id
    RETURNING job.queue_id
  ), claimed_individual AS (
    UPDATE individual_script_jobs AS job
    SET status = 'processing', lock_token = claim_token, locked_at_utc = now(),
        attempts = job.attempts + 1, updated_at_utc = now()
    FROM candidate
    WHERE candidate.job_type = 'individual' AND job.article_id = candidate.subject_id
    RETURNING job.article_id
  )
  SELECT 'daily'::TEXT, queue_id FROM claimed_daily
  UNION ALL
  SELECT 'individual'::TEXT, article_id FROM claimed_individual;
END;
$$;
