
-- policies_day2.sql
PRAGMA foreign_keys = ON;

------------------------------------------------------------
-- [Admin Policies]

-- 1) admin만 챌린지 생성 가능
DROP TRIGGER IF EXISTS trg_challenge_admin_only;
CREATE TRIGGER trg_challenge_admin_only
BEFORE INSERT ON challenges
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'only admins can create challenges')
  WHERE NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = NEW.created_by AND role = 'admin'
  );
END;

------------------------------------------------------------
-- [Submission Policies]

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

-- 댓글 알림
CREATE TRIGGER trg_notify_on_comment
AFTER INSERT ON comments
FOR EACH ROW
BEGIN
  INSERT INTO notifications (id, user_id, type, payload_json)
  SELECT lower(hex(randomblob(16))), s.user_id, 'comment',
         json_object('submission_id', NEW.submission_id, 'comment_id', NEW.id)
    FROM submissions s
   WHERE s.id = NEW.submission_id
     AND s.user_id <> NEW.user_id
     AND NEW.status = 'active';
END;

-- 좋아요 마일스톤 알림 (10/50/100)
CREATE TRIGGER trg_notify_on_like_milestones
AFTER INSERT ON likes
FOR EACH ROW
BEGIN
  INSERT INTO notifications (id, user_id, type, payload_json)
  SELECT lower(hex(randomblob(16))), s.user_id, 'like_summary',
         json_object('submission_id', s.id, 'like_count', s.like_count)
    FROM submissions s
   WHERE s.id = NEW.submission_id
     AND s.like_count IN (10, 50, 100);
END;

-- (선택) 챌린지 상태 업데이트가 closed로 바뀔 때 알림 생성
CREATE TRIGGER trg_notify_on_challenge_closed
AFTER UPDATE OF status ON challenges
FOR EACH ROW
BEGIN
  INSERT INTO notifications (id, user_id, type, payload_json)
  SELECT lower(hex(randomblob(16))), c.created_by, 'challenge_closed',
         json_object('challenge_id', NEW.id, 'title', NEW.title, 'closed_at', datetime('now'))
    FROM challenges c
   WHERE c.id = NEW.id
     AND OLD.status <> 'closed'
     AND NEW.status = 'closed';
END;


-- (10) notifications.channel 허용값 검증 (email, push)
------------------------------------------------------------

CREATE TRIGGER trg_notifications_channel_check
BEFORE INSERT ON notifications
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'notifications.channel must be one of: email, push')
  WHERE NEW.channel NOT IN ('email','push');
END;

CREATE TRIGGER trg_notifications_channel_update_check
BEFORE UPDATE OF channel ON notifications
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'notifications.channel must be one of: email, push')
  WHERE NEW.channel NOT IN ('email','push');
END;



-- 1-1) 유저가 새 제출을 만들 때, 해당 챌린지의 규칙(max_submissions_per_user)만 적용
CREATE TRIGGER trg_limit_submissions_per_rule_insert
BEFORE INSERT ON submissions
FOR EACH ROW
BEGIN
  -- 규칙이 없으면 기본 1개 허용
  SELECT RAISE(ABORT,
    'submission limit reached (max ' ||
      COALESCE( (SELECT max_submissions_per_user
                 FROM challenge_rules
                 WHERE challenge_id = NEW.challenge_id), 1
               ) || ')'
  )
  WHERE (
    SELECT COUNT(1)
    FROM submissions s
    WHERE s.challenge_id = NEW.challenge_id
      AND s.user_id = NEW.user_id
      AND s.status IN ('active','hidden')   -- 삭제 글은 제외
  ) >= COALESCE( (SELECT max_submissions_per_user
                  FROM challenge_rules
                  WHERE challenge_id = NEW.challenge_id), 1 );
END;

-- 1-2) )상태 변경(UPDATE) 시에도 상한 재검사
CREATE TRIGGER trg_limit_submissions_per_rule_status_update
BEFORE UPDATE OF status ON submissions
FOR EACH ROW
BEGIN
  -- active/hidden 으로 전환하려 할 때만 검사
  SELECT RAISE(ABORT,
    'submission limit reached on status change (max ' ||
      COALESCE( (SELECT max_submissions_per_user
                 FROM challenge_rules
                 WHERE challenge_id = OLD.challenge_id), 1
               ) || ')'
  )
  WHERE NEW.status IN ('active','hidden')
    AND (
      SELECT COUNT(1)
      FROM submissions s
      WHERE s.challenge_id = OLD.challenge_id
        AND s.user_id = OLD.user_id
        AND s.status IN ('active','hidden')
        -- 지금 이 레코드가 이미 active/hidden이었다면, 자기 자신을 제외하고 세야 함
        -- (OLD.status가 active/hidden이면 count에서 1 빼고 비교)
    ) - CASE WHEN OLD.status IN ('active','hidden') THEN 1 ELSE 0 END
      >= COALESCE( (SELECT max_submissions_per_user
                    FROM challenge_rules
                    WHERE challenge_id = OLD.challenge_id), 1 );
END;

-- 1-3) 이상만 허용 (원한다면 상한(예: 50)도 둘 수 있음)
CREATE TRIGGER trg_rules_max_submissions_check_insert
BEFORE INSERT ON challenge_rules
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'max_submissions_per_user must be >= 1')
  WHERE NEW.max_submissions_per_user IS NULL OR NEW.max_submissions_per_user < 1;
END;

CREATE TRIGGER trg_rules_max_submissions_check_update
BEFORE UPDATE OF max_submissions_per_user ON challenge_rules
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'max_submissions_per_user must be >= 1')
  WHERE NEW.max_submissions_per_user IS NULL OR NEW.max_submissions_per_user < 1;
END;

-- 1-4) (성능 최적화) submissions 테이블에 (challenge_id, user_id, status) 복합 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_submissions_challenge_user_status
  ON submissions (challenge_id, user_id, status);

-- 4-7) reports 조회 가속
CREATE INDEX IF NOT EXISTS idx_reports_target_status_created
  ON reports (target_type, target_id, status, created_at DESC);

-- 4-8) notifications 조회 가속
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_delivery
  ON notifications (delivery_status);



-- 2) 수정(Edit) 24시간 제한 (모든 사용자 동일)
--   - 최초 등록 후 24시간 이내에만 이미지/링크/캡션 수정 허용
CREATE TRIGGER trg_edit_window_submissions
BEFORE UPDATE OF image_url, youtube_url, instagram_url, caption ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'edit window closed (24h)')
  WHERE datetime('now') > datetime(OLD.created_at, '+24 hours');
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
    AND datetime('now') < datetime(COALESCE(NEW.created_at, CURRENT_TIMESTAMP), '+1 hours');
END;

-- 4) 노출(visible=active) 전환 제한
--   - 일반 사용자의 게시물을 active로 바꾸려면 생성 후 1시간이 지나야 함
--   - admin이 작성한 게시물은 1시간 내에도 active 허용
CREATE TRIGGER trg_visibility_activate_1h
BEFORE UPDATE OF status ON submissions
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'cannot activate before 1h (author is not admin)')
  WHERE NEW.status = 'active'
    AND (SELECT role FROM users WHERE id = OLD.user_id) <> 'admin'
    AND datetime('now') < datetime(OLD.created_at, '+1 hours');
END;

-- 5) 미디어 타입 정책 (challenge_rules.allow_media_types)
-- 허용 타입 이외의 필드 사용 방지
CREATE TRIGGER IF NOT EXISTS trg_media_types_on_insert
BEFORE INSERT ON submissions
FOR EACH ROW
BEGIN
  --image url 비어있으면 거부
  SELECT RAISE(ABORT, 'image_url is required')
  WHERE COALESCE(NEW.image_url, '') = '';
END;

-- 6) UPDATE 시: image_url 을 비우는 변경 금지
CREATE TRIGGER trg_submission_require_image_update
BEFORE UPDATE OF image_url ON submissions
FOR EACH ROW
BEGIN
  -- 기존엔 이미지가 있었는데, 업데이트 후에 이미지가 비어있으면 거부
  SELECT RAISE(ABORT, 'image_url cannot be removed')
  WHERE COALESCE(OLD.image_url, '') <> '' AND COALESCE(NEW.image_url, '') = '';
END;
-- ※ 인스타그램/유튜브 URL은 “값이 있으면 저장, 없어도 통과”.
--    별도 타입 허용 검사는 제거 → 정책 단순화(항상 이미지 필수만 강제)

-- 8) 챌린지 기간 내 제출만 허용
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

-- (9) 챌린지 시간 무결성 보장 (start_at < end_at)
------------------------------------------------------------

CREATE TRIGGER trg_challenges_time_valid_insert
BEFORE INSERT ON challenges
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'end_at must be after start_at')
  WHERE datetime(NEW.end_at) <= datetime(NEW.start_at);
END;

CREATE TRIGGER trg_challenges_time_valid_update
BEFORE UPDATE OF start_at, end_at ON challenges
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'end_at must be after start_at')
  WHERE datetime(NEW.end_at) <= datetime(NEW.start_at);
END;




-- 9-1) 좋아요는 active 상태의 게시물에만 허용
CREATE TRIGGER IF NOT EXISTS trg_like_only_active_submission
BEFORE INSERT ON likes
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'cannot like a non-active submission')
  WHERE EXISTS (
    SELECT 1 FROM submissions s WHERE s.id = NEW.submission_id AND s.status <> 'active'
  );
END;

-- 9-2) 좋아요 추가 → like_count +1
CREATE TRIGGER trg_like_insert_inc
AFTER INSERT ON likes
FOR EACH ROW
BEGIN
  UPDATE submissions
     SET like_count = like_count + 1
   WHERE id = NEW.submission_id;
END;

-- 9-3) 좋아요 삭제 → like_count -1 (최소 0 보장)
CREATE TRIGGER trg_like_delete_dec
AFTER DELETE ON likes
FOR EACH ROW
BEGIN
  UPDATE submissions
     SET like_count = CASE WHEN like_count > 0 THEN like_count - 1 ELSE 0 END
   WHERE id = OLD.submission_id;
END;

-- 9-4) 자기 게시물 좋아요 금지
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

-- 10-1) 댓글은 active 상태의 게시물에만 허용
CREATE TRIGGER IF NOT EXISTS trg_comment_only_active_submission
BEFORE INSERT ON comments
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'cannot comment on a non-active submission')
  WHERE EXISTS (
    SELECT 1 FROM submissions s WHERE s.id = NEW.submission_id AND s.status <> 'active'
  );
END;

-- 10-2) 댓글의 부모 댓글도 active 상태여야 함 (대댓글 허용)
CREATE TRIGGER IF NOT EXISTS trg_comment_parent_active 
BEFORE INSERT ON comments
FOR EACH ROW
BEGIN
  SELECT RAISE(ABORT, 'parent comment must be active')
  WHERE NEW.parent_comment_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM comments c
      WHERE c.id = NEW.parent_comment_id AND c.status <> 'active'
    );
END;

--- 10-3) 부모 댓글은 같은 게시물에 속해야 함
CREATE TRIGGER trg_comment_parent_same_submission
BEFORE INSERT ON comments
FOR EACH ROW
WHEN NEW.parent_comment_id IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'parent_comment must belong to the same submission')
  WHERE EXISTS (
    SELECT 1
    FROM comments pc
    WHERE pc.id = NEW.parent_comment_id
      AND pc.submission_id <> NEW.submission_id
  );
END;

-- 10-4) UPDATE로 parent_comment_id를 바꾸는 경우도 대비
CREATE TRIGGER trg_comment_parent_same_submission_update
BEFORE UPDATE OF parent_comment_id ON comments
FOR EACH ROW
WHEN NEW.parent_comment_id IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'parent_comment must belong to the same submission')
  WHERE EXISTS (
    SELECT 1
    FROM comments pc
    WHERE pc.id = NEW.parent_comment_id
      AND pc.submission_id <> NEW.submission_id
  );
END;

-- 10-5) 댓글 추가 → comment_count +1
-- 댓글 삭제(active였던 것만 감소)
CREATE TRIGGER trg_comment_delete_dec
AFTER DELETE ON comments
FOR EACH ROW
BEGIN
  UPDATE submissions
     SET comment_count = CASE WHEN comment_count > 0 THEN comment_count - 1 ELSE 0 END
   WHERE id = OLD.submission_id
     AND OLD.status = 'active';
END;
-- 댓글 상태 변경에 따른 증감
CREATE TRIGGER trg_comment_status_flip
AFTER UPDATE OF status ON comments
FOR EACH ROW
BEGIN
  -- active -> (hidden/deleted 등) : -1
  UPDATE submissions
     SET comment_count = CASE WHEN comment_count > 0 THEN comment_count - 1 ELSE 0 END
   WHERE id = NEW.submission_id
     AND OLD.status = 'active'
     AND NEW.status <> 'active';
  -- (hidden/deleted 등) -> active : +1
  UPDATE submissions
     SET comment_count = comment_count + 1
   WHERE id = NEW.submission_id
     AND OLD.status <> 'active'
     AND NEW.status = 'active';
END;

------------------------------------------------------------
-- [Moderation Policies]

-- 4-2) 신고 임계치 테이블
CREATE TABLE IF NOT EXISTS moderation_rules (
  target_type TEXT PRIMARY KEY,      -- 'submission' / 'comment'
  threshold   INTEGER NOT NULL       -- 예: 5
);

-- 기본값(필요 시 값 바꿔도 됨)
INSERT OR IGNORE INTO moderation_rules(target_type, threshold) VALUES ('submission', 10);
INSERT OR IGNORE INTO moderation_rules(target_type, threshold) VALUES ('comment', 10);

-- 4-3) 신고 후 자동 블록 (submission)
DROP TRIGGER IF EXISTS trg_reports_autoblock_submission;
CREATE TRIGGER trg_reports_autoblock_submission
AFTER INSERT ON reports
FOR EACH ROW
WHEN NEW.target_type = 'submission'
BEGIN
  UPDATE submissions
  SET status = 'blocked'
  WHERE id = NEW.target_id
    AND (
      SELECT COUNT(*) FROM reports
      WHERE target_type = 'submission'
        AND target_id = NEW.target_id
        AND status IN ('open','reviewed')
    ) >= (SELECT threshold FROM moderation_rules WHERE target_type='submission');
END;

-- 4-4) 신고 후 자동 블록 (comment)
DROP TRIGGER IF EXISTS trg_reports_autoblock_comment;
CREATE TRIGGER trg_reports_autoblock_comment
AFTER INSERT ON reports
FOR EACH ROW
WHEN NEW.target_type = 'comment'
BEGIN
  UPDATE comments
  SET status = 'blocked'
  WHERE id = NEW.target_id
    AND (
      SELECT COUNT(*) FROM reports
      WHERE target_type = 'comment'
        AND target_id = NEW.target_id
        AND status IN ('open','reviewed')
    ) >= (SELECT threshold FROM moderation_rules WHERE target_type='comment');
END;
------------------------------------------------------------