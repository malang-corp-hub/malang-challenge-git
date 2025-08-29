
-- policies_day2.sql
PRAGMA foreign_keys = ON;

-- 0) 권장: 상태/타입 값의 일관성 (CHECK 대체용 트리거)

-- submissions.status 허용 값: active, hidden, deleted
CREATE TRIGGER IF NOT EXISTS trg_submissions_status_check
BEFORE INSERT ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'submissions.status must be one of: active, hidden, deleted')
  WHERE NEW.status NOT IN ('active','hidden','deleted');
END;

CREATE TRIGGER IF NOT EXISTS trg_submissions_status_update_check
BEFORE UPDATE OF status ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'submissions.status must be one of: active, hidden, deleted')
  WHERE NEW.status NOT IN ('active','hidden','deleted');
END;

-- comments.status 허용 값: active, hidden, deleted
CREATE TRIGGER IF NOT EXISTS trg_comments_status_check
BEFORE INSERT ON comments
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'comments.status must be one of: active, hidden, deleted')
  WHERE NEW.status NOT IN ('active','hidden','deleted');
END;

CREATE TRIGGER IF NOT EXISTS trg_comments_status_update_check
BEFORE UPDATE OF status ON comments
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'comments.status must be one of: active, hidden, deleted')
  WHERE NEW.status NOT IN ('active','hidden','deleted');
END;

-- notifications.type 허용 값: comment, like_summary, challenge_closed
CREATE TRIGGER IF NOT EXISTS trg_notifications_type_check
BEFORE INSERT ON notifications
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'notifications.type must be one of: comment, like_summary, challenge_closed')
  WHERE NEW.type NOT IN ('comment','like_summary','challenge_closed');
END;

CREATE TRIGGER IF NOT EXISTS trg_notifications_type_update_check
BEFORE UPDATE OF type ON notifications
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'notifications.type must be one of: comment, like_summary, challenge_closed')
  WHERE NEW.type NOT IN ('comment','like_summary','challenge_closed');
END;

-- 1) 사용자별-챌린지별 제출 상한 (challenge_rules.max_submissions_per_user)
CREATE TRIGGER trg_limit_submissions_max10
BEFORE INSERT ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'submission limit reached (max 10)')
  WHERE (
    SELECT COUNT(1)
    FROM submissions s
    WHERE s.challenge_id = NEW.challenge_id
      AND s.user_id = NEW.user_id
      AND s.status IN ('active', 'hidden')
  ) >= MIN(
    COALESCE((SELECT max_submissions_per_user 
              FROM challenge_rules
              WHERE challenge_id = NEW.challenge_id), 1),
    10
  );
END;

-- 2) 수정(Edit) 24시간 제한 (모든 사용자 동일)
--   - 최초 등록 후 24시간 이내에만 이미지/링크/캡션 수정 허용
CREATE TRIGGER IF NOT EXISTS trg_edit_window_submissions
BEFORE UPDATE OF image_url, youtube_url, instagram_url, caption ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'edit window closed (24h)')
  WHERE datetime('Now') > datetime(OLD.created_at, '+24 hours');
END;

-- 3) 삽입 직후 노출 강제 제어
--   - 일반 사용자(author가 admin이 아님) & 등록 시점으로부터 1시간 이전이면 무조건 hidden으로 고정
--   - admin이 작성한 게시물은 예외(즉시 active 허용)
CREATE TRIGGER trg_visibility_gate_after_insert
AFTER INSERT ON submissions
FOR EACH ROW
BEGIN
  UPDATE submissions
  SET status = 'hidden'
  WHERE id = NEW.id
    AND (SELECT role FROM users WHERE id = NEW.user_id) <> 'admin'
    AND datetime('Now') < datetime(COALESCE(NEW.created_at, CURRENT_TIMESTAMP), '+1 hours');
END;

-- 4) 노출(visible=active) 전환 제한
--   - 일반 사용자의 게시물을 active로 바꾸려면 생성 후 1시간이 지나야 함
--   - admin이 작성한 게시물은 1시간 내에도 active 허용
CREATE TRIGGER trg_visibility_activate_24h
BEFORE UPDATE OF status ON submission
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'cannot activate before 1h (author is not admin)')
  WHERE NEW.status = 'active'
    AND (SELECT role FROM users WHERE id = OLD.user_id) <> 'admin'
    AND datetime('Now') < datetime(OLD.created_at, '+1 hours')
END;

-- 5) 미디어 타입 정책 (challenge_rules.allow_media_types)
-- 허용 타입 이외의 필드 사용 방지
CREATE TRIGGER IF NOT EXISTS trg_media_types_on_insert
BEFORE INSERT ON submissions
FOR EACH ROW
BEGIN
  -- 이미지가 허용되지 않으면 image_url 사용 금지
  SELECT RAISE(ABORT, 'image_url not allowed by challenge rules')
  WHERE NEW.image_url IS NOT NULL AND
        (SELECT INSTR(LOWER(allow_media_types), 'image') = 0 FROM challenge_rules WHERE challenge_id = NEW.challenge_id);

  -- 인스타그램이 허용되지 않으면 instagram_url 금지
  SELECT RAISE(ABORT, 'instagram_url not allowed by challenge rules')
  WHERE NEW.instagram_url IS NOT NULL AND
        (SELECT INSTR(LOWER(allow_media_types), 'instagram') = 0 FROM challenge_rules WHERE challenge_id = NEW.challenge_id);

  -- 유튜브가 허용되지 않으면 youtube_url 금지
  SELECT RAISE(ABORT, 'youtube_url not allowed by challenge rules')
  WHERE NEW.youtube_url IS NOT NULL AND
        (SELECT INSTR(LOWER(allow_media_types), 'youtube') = 0 FROM challenge_rules WHERE challenge_id = NEW.challenge_id);
END;

CREATE TRIGGER IF NOT EXISTS trg_media_types_on_update
BEFORE UPDATE OF image_url, instagram_url, youtube_url ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'image_url not allowed by challenge rules')
  WHERE NEW.image_url IS NOT NULL AND
        (SELECT INSTR(LOWER(allow_media_types), 'image') = 0 FROM challenge_rules WHERE challenge_id = NEW.challenge_id);

  SELECT RAISE(ABORT, 'instagram_url not allowed by challenge rules')
  WHERE NEW.instagram_url IS NOT NULL AND
        (SELECT INSTR(LOWER(allow_media_types), 'instagram') = 0 FROM challenge_rules WHERE challenge_id = NEW.challenge_id);

  SELECT RAISE(ABORT, 'youtube_url not allowed by challenge rules')
  WHERE NEW.youtube_url IS NOT NULL AND
        (SELECT INSTR(LOWER(allow_media_types), 'youtube') = 0 FROM challenge_rules WHERE challenge_id = NEW.challenge_id);
END;

-- 6) 자기 게시물 좋아요 금지 (선택 정책)
CREATE TRIGGER IF NOT EXISTS trg_no_self_like
BEFORE INSERT ON likes
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'authors cannot like their own submissions')
  WHERE EXISTS (
    SELECT 1 FROM submissions s
    WHERE s.id = NEW.submission_id AND s.user_id = NEW.user_id
  );
END;

-- 7) 챌린지 기간 내 제출만 허용
CREATE TRIGGER IF NOT EXISTS trg_submission_within_challenge_window
BEFORE INSERT ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'submission must be created within challenge time window')
  WHERE NOT EXISTS (
    SELECT 1 FROM challenges c
    WHERE c.id = NEW.challenge_id
      AND datetime(COALESCE(NEW.created_at, CURRENT_TIMESTAMP)) BETWEEN c.start_at AND c.end_at
  );
END;

-- 8) 댓글/좋아요는 active 상태의 게시물에만 허용
CREATE TRIGGER IF NOT EXISTS trg_like_only_active_submission
BEFORE INSERT ON likes
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'cannot like a non-active submission')
  WHERE EXISTS (
    SELECT 1 FROM submissions s WHERE s.id = NEW.submission_id AND s.status <> 'active'
  );
END;

CREATE TRIGGER IF NOT EXISTS trg_comment_only_active_submission
BEFORE INSERT ON comments
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'cannot comment on a non-active submission')
  WHERE EXISTS (
    SELECT 1 FROM submissions s WHERE s.id = NEW.submission_id AND s.status <> 'active'
  );
END;
