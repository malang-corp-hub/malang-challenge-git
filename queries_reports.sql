
-----------------------------------------------------
-- 챌린지 리더보드 (순위/동점 처리)
-- :challenge_id 바인딩
WITH ranked AS (
  SELECT
    s.id              AS submission_id,
    s.user_id,
    u.name            AS user_name,
    s.like_count,
    s.comment_count,
    s.created_at,
    DENSE_RANK() OVER (
      ORDER BY s.like_count DESC, s.created_at ASC
    )                 AS rank
  FROM submissions s
  JOIN users u ON u.id = s.user_id
  WHERE s.challenge_id = :challenge_id
    AND s.status = 'active'
)
SELECT * FROM ranked
ORDER BY rank, created_at ASC;

-----------------------------------------------------
-- 유저 활동 요약 (작성.받은좋아요.단댓글)
-- :user_id 바인딩 (특정 유저)
WITH my_posts AS (
  SELECT id FROM submissions WHERE user_id = :user_id
),
received_likes AS (
  SELECT COUNT(*) AS like_received
  FROM likes l
  JOIN my_posts p ON p.id = l.submission_id
),
made_likes AS (
  SELECT COUNT(*) AS like_made
  FROM likes WHERE user_id = :user_id
),
made_comments AS (
  SELECT COUNT(*) AS comment_made
  FROM comments WHERE user_id = :user_id AND status='active'
),
last_activities AS (
  SELECT MAX(ts) AS last_activity_at FROM (
    SELECT MAX(created_at) AS ts FROM submissions WHERE user_id=:user_id
    UNION ALL
    SELECT MAX(created_at) FROM likes WHERE user_id=:user_id
    UNION ALL
    SELECT MAX(created_at) FROM comments WHERE user_id=:user_id
  )
)
SELECT
  (SELECT COUNT(*) FROM submissions WHERE user_id=:user_id AND status='active') AS posts,
  (SELECT like_received FROM received_likes) AS likes_received,
  (SELECT like_made FROM made_likes) AS likes_made,
  (SELECT comment_made FROM made_comments) AS comments_made,
  (SELECT last_activity_at FROM last_activities) AS last_activity_at;

-----------------------------------------------------
-- 주간 좋아요 요약 (보낸/받은)
-- :since, :until (예: 지난 7일), :challenge_id (옵션)
-- liker 관점(보낸 좋아요)
SELECT
  l.user_id AS liker_id,
  u.name    AS liker_name,
  COUNT(*)  AS likes_given
FROM likes l
JOIN users u ON u.id = l.user_id
JOIN submissions s ON s.id = l.submission_id
WHERE l.created_at >= :since AND l.created_at < :until
  AND (:challenge_id IS NULL OR s.challenge_id = :challenge_id)
GROUP BY l.user_id, u.name
ORDER BY likes_given DESC;

-- author 관점(받은 좋아요)
SELECT
  s.user_id AS author_id,
  u.name    AS author_name,
  COUNT(*)  AS likes_received
FROM likes l
JOIN submissions s ON s.id = l.submission_id
JOIN users u ON u.id = s.user_id
WHERE l.created_at >= :since AND l.created_at < :until
  AND (:challenge_id IS NULL OR s.challenge_id = :challenge_id)
GROUP BY s.user_id, u.name
ORDER BY likes_received DESC;


-----------------------------------------------------
-- 댓글 스레드 뷰 (부모–자식·최신 답글)
-- 특정 게시물의 1~2단 댓글 트리
-- :submission_id 바인딩
WITH roots AS (
  SELECT
    c.id,
    c.user_id,
    u.name AS user_name,
    c.body,
    c.created_at
  FROM comments c
  JOIN users u ON u.id = c.user_id
  WHERE c.submission_id = :submission_id
    AND c.parent_comment_id IS NULL
    AND c.status='active'
),
children AS (
  SELECT
    c.parent_comment_id   AS root_id,
    c.id,
    c.user_id,
    u.name AS user_name,
    c.body,
    c.created_at
  FROM comments c
  JOIN users u ON u.id = c.user_id
  WHERE c.submission_id = :submission_id
    AND c.parent_comment_id IS NOT NULL
    AND c.status='active'
)
SELECT
  r.id            AS root_id,
  r.user_name     AS root_author,
  r.body          AS root_body,
  r.created_at    AS root_created_at,
  COUNT(ch.id)    AS reply_count,
  MAX(ch.created_at) AS last_reply_at
FROM roots r
LEFT JOIN children ch ON ch.root_id = r.id
GROUP BY r.id
ORDER BY r.created_at ASC;

-----------------------------------------------------
-- 챌린지 헬스 대시보드 (핵심 지표 한방)
-- :challenge_id 바인딩
WITH base AS (
  SELECT s.*
  FROM submissions s
  WHERE s.challenge_id = :challenge_id AND s.status='active'
),
user_set AS (
  SELECT DISTINCT user_id FROM base
),
likes_all AS (
  SELECT l.*
  FROM likes l JOIN base b ON b.id = l.submission_id
),
comments_all AS (
  SELECT c.*
  FROM comments c JOIN base b ON b.id = c.submission_id
  WHERE c.status='active'
)
SELECT
  (SELECT COUNT(*) FROM base)                     AS submissions,
  (SELECT COUNT(*) FROM user_set)                 AS active_users,
  (SELECT COALESCE(AVG(like_count),0) FROM base)  AS avg_likes_per_post,
  (SELECT COALESCE(AVG(comment_count),0) FROM base) AS avg_comments_per_post,
  (SELECT COUNT(*) FROM likes_all)                AS total_likes,
  (SELECT COUNT(*) FROM comments_all)             AS total_comments,
  (SELECT MIN(created_at) FROM base)              AS first_post_at,
  (SELECT MAX(created_at) FROM base)              AS last_post_at;

-----------------------------------------------------
-- 참여 퍼널 (제출→남의 글 좋아요→댓글)
-- :challenge_id 바인딩
WITH subs AS (
  SELECT DISTINCT user_id FROM submissions
  WHERE challenge_id=:challenge_id AND status='active'
),
liked_others AS (
  SELECT DISTINCT l.user_id
  FROM likes l
  JOIN submissions s ON s.id = l.submission_id
  WHERE s.challenge_id=:challenge_id
    AND l.user_id <> s.user_id  -- 자기글 좋아요 제외
),
commenters AS (
  SELECT DISTINCT c.user_id
  FROM comments c
  JOIN submissions s ON s.id = c.submission_id
  WHERE s.challenge_id=:challenge_id AND c.status='active'
)
SELECT
  (SELECT COUNT(*) FROM subs)                                         AS step1_submitters,
  (SELECT COUNT(*) FROM subs WHERE user_id IN (SELECT user_id FROM liked_others)) AS step2_liked_others,
  (SELECT COUNT(*) FROM subs WHERE user_id IN (SELECT user_id FROM commenters))   AS step3_commenters;


-----------------------------------------------------
-- 상위 기여자 (작성+받은좋아요 복합 점수)
-- :challenge_id 바인딩
WITH posts AS (
  SELECT s.user_id, COUNT(*) AS posts, SUM(s.like_count) AS likes_received
  FROM submissions s
  WHERE s.challenge_id=:challenge_id AND s.status='active'
  GROUP BY s.user_id
),
likes_made AS (
  SELECT l.user_id, COUNT(*) AS likes_given
  FROM likes l
  JOIN submissions s ON s.id = l.submission_id
  WHERE s.challenge_id=:challenge_id
  GROUP BY l.user_id
)
SELECT
  u.id,
  u.name,
  COALESCE(p.posts,0)          AS posts,
  COALESCE(p.likes_received,0) AS likes_received,
  COALESCE(lm.likes_given,0)   AS likes_given,
  -- 가중치 원하는대로 조정 (예: 글1, 받은좋아요0.5, 준좋아요0.2)
  (COALESCE(p.posts,0)*1.0 + COALESCE(p.likes_received,0)*0.5 + COALESCE(lm.likes_given,0)*0.2) AS score
FROM users u
LEFT JOIN posts p ON p.user_id = u.id
LEFT JOIN likes_made lm ON lm.user_id = u.id
WHERE p.posts IS NOT NULL OR lm.likes_given IS NOT NULL
ORDER BY score DESC
LIMIT 20;


-----------------------------------------------------
-- 통합 활동 피드 (글/좋아요/댓글)
-- :since, :until 바인딩
SELECT 'submission' AS type, s.id AS object_id, s.user_id, u.name AS user_name, s.created_at
FROM submissions s JOIN users u ON u.id = s.user_id
WHERE s.created_at >= :since AND s.created_at < :until
UNION ALL
SELECT 'like', CAST(l.rowid AS TEXT), l.user_id, u.name, l.created_at
FROM likes l JOIN users u ON u.id = l.user_id
WHERE l.created_at >= :since AND l.created_at < :until
UNION ALL
SELECT 'comment', c.id, c.user_id, u.name, c.created_at
FROM comments c JOIN users u ON u.id = c.user_id
WHERE c.created_at >= :since AND c.created_at < :until AND c.status='active'
ORDER BY created_at DESC
LIMIT 200;


-----------------------------------------------------
-- 신고 현황 (무슨 대상이 얼마나?)
-- :since, :until (옵션)
SELECT
  target_type,            -- 'submission' | 'comment' 등
  COUNT(*)        AS report_count,
  SUM(CASE WHEN status='open' THEN 1 ELSE 0 END)  AS open_count,
  MIN(created_at) AS first_report_at,
  MAX(created_at) AS last_report_at
FROM reports
WHERE (:since IS NULL OR created_at >= :since)
  AND (:until IS NULL OR created_at < :until)
GROUP BY target_type
ORDER BY report_count DESC;


-----------------------------------------------------
-- 알림 발송 대기열 (pending)
SELECT
  n.id,
  n.user_id,
  u.name AS user_name,
  n.type,
  n.channel,
  n.delivery_status,
  n.created_at
FROM notifications n
JOIN users u ON u.id = n.user_id
WHERE n.delivery_status='pending'
ORDER BY n.created_at ASC
LIMIT 200;

-----------------------------------------------------
-- 리더보드 뷰(재사용):
CREATE VIEW IF NOT EXISTS v_challenge_leaderboard AS
SELECT
  s.challenge_id,
  s.id          AS submission_id,
  s.user_id,
  u.name        AS user_name,
  s.like_count,
  s.comment_count,
  s.created_at,
  DENSE_RANK() OVER (
    PARTITION BY s.challenge_id
    ORDER BY s.like_count DESC, s.created_at ASC
  )            AS rank
FROM submissions s
JOIN users u ON u.id = s.user_id
WHERE s.status='active';


-----------------------------------------------------
-- 읽기 성능 인덱스:
-- 유저별 글 조회
CREATE INDEX IF NOT EXISTS idx_submissions_user_created
  ON submissions (user_id, created_at DESC);

-- 부모댓글 조회
CREATE INDEX IF NOT EXISTS idx_comments_parent_created
  ON comments (parent_comment_id, created_at DESC);

-- 게시물별 좋아요 최신순
CREATE INDEX IF NOT EXISTS idx_likes_submission_created
  ON likes (submission_id, created_at DESC);


