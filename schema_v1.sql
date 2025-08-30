-- schema_v1.sql (요약본)
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  naver_id TEXT UNIQUE,
  naver_login TEXT,
  name TEXT NOT NULL,
  email TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'user',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at DATETIME
);

CREATE TABLE challenges (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  cover_image_url TEXT,
  start_at DATETIME NOT NULL,
  end_at DATETIME NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled',
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE challenge_rules (
  id TEXT PRIMARY KEY,
  challenge_id TEXT NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  max_submissions_per_user INTEGER DEFAULT 1,
  allow_media_types TEXT DEFAULT 'image',
  required_aspect_ratio TEXT DEFAULT '1:1,4:5,1.91:1',
  min_resolution_px INTEGER,
  aspect_ratio_enforcement TEXT NOT NULL DEFAULT 'recommended'
);

CREATE TABLE submissions (
  id TEXT PRIMARY KEY,
  challenge_id TEXT NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  image_url TEXT,
  youtube_url TEXT,
  instagram_url TEXT,
  caption TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  like_count INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_submissions_challenge_created
  ON submissions (challenge_id, created_at DESC);

CREATE INDEX idx_submissions_like_created
  ON submissions (challenge_id, like_count DESC, created_at DESC);

CREATE TABLE likes (
  submission_id TEXT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (submission_id, user_id)
);

CREATE INDEX idx_likes_user_created
  ON likes (user_id, created_at DESC);

CREATE TABLE comments (
  id TEXT PRIMARY KEY,
  submission_id TEXT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_comment_id TEXT REFERENCES comments(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_comments_submission_created
  ON comments (submission_id, created_at DESC);

CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  reporter_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'open',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,               -- 'comment','like_summary','challenge_closed'
  channel TEXT NOT NULL DEFAULT 'email',
  payload_json TEXT,
  delivery_status TEXT NOT NULL DEFAULT 'pending',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at DATETIME
);
