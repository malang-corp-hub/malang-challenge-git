
-- seed_day2.sql
PRAGMA foreign_keys = ON;

-- 1) Users
INSERT INTO users (id, naver_id, naver_login, name, email, role)
VALUES
  ('u_admin', 'nav-0001', 'admin_login', '관리자', 'admin@example.com', 'admin'),
  ('u_kyoo',  'nav-1001', 'kyoo_login',  '뀨말랑', 'kyoo@example.com',  'user'),
  ('u_mint',  'nav-1002', 'mint_login',  '민트',   'mint@example.com',  'user');

-- 2) Challenges
-- 진행중 챌린지: 8월 20일 ~ 8월 31일
INSERT INTO challenges (id, title, description, cover_image_url, start_at, end_at, status, created_by)
VALUES
  ('ch_0820', '8월 활용꾸 챌린지', '레트로/빈티지 무드로 다꾸하기', 'https://example.com/covers/0820.jpg',
   '2025-08-20 00:00:00', '2025-08-31 23:59:59', 'active', 'u_admin'),
  ('ch_0901', '9월 활용꾸 챌린지', '파스텔 무드의 다꾸', 'https://example.com/covers/0901.jpg',
   '2025-09-01 00:00:00', '2025-09-15 23:59:59', 'scheduled', 'u_admin');

-- 3) Challenge Rules
INSERT INTO challenge_rules (id, challenge_id, max_submissions_per_user, allow_edit_until_minutes, allow_media_types, required_aspect_ratio, min_resolution_px, aspect_ratio_enforcement)
VALUES
  ('rule_0820', 'ch_0820', 2, 30, 'image,instagram,youtube', '1:1,4:5,1.91:1', 1080, 'recommended'),
  ('rule_0901', 'ch_0901', 1, 10, 'image', '1:1', 1080, 'required');

-- 4) Submissions (샘플)
INSERT INTO submissions (id, challenge_id, user_id, image_url, instagram_url, youtube_url, caption, status, like_count, comment_count, created_at)
VALUES
  ('sub_001', 'ch_0820', 'u_kyoo', 'https://example.com/img/sub_001.jpg', 'https://instagram.com/p/abc', NULL,
   '레드 포인트 레트로 다꾸 ✨', 'active', 0, 0, '2025-08-22 06:00:00'),
  ('sub_002', 'ch_0820', 'u_mint', 'https://example.com/img/sub_002.jpg', NULL, 'https://youtube.com/watch?v=xyz',
   '빈티지 스티커로 꾸며봤어요', 'active', 0, 0, '2025-08-22 06:30:00');

-- 5) Likes
INSERT INTO likes (submission_id, user_id, created_at) VALUES
  ('sub_001', 'u_mint', '2025-08-22 07:00:00'),
  ('sub_002', 'u_kyoo', '2025-08-22 07:05:00');

-- 6) Comments
INSERT INTO comments (id, submission_id, user_id, body, status, created_at) VALUES
  ('cmt_001', 'sub_001', 'u_mint', '레드 포인트 너무 예뻐요!', 'active', '2025-08-22 07:10:00'),
  ('cmt_002', 'sub_002', 'u_kyoo', '빈티지 무드 최고🧡', 'active', '2025-08-22 07:12:00');

-- 7) Reports (예시)
INSERT INTO reports (id, target_type, target_id, reporter_id, reason, status, created_at) VALUES
  ('rpt_001', 'submission', 'sub_002', 'u_kyoo', '부적절한 링크 의심', 'open', '2025-08-22 07:20:00');

-- 8) Notifications (예시)
INSERT INTO notifications (id, user_id, type, channel, payload_json, delivery_status, created_at)
VALUES
  ('ntf_001', 'u_kyoo', 'comment', 'email', '{"submission_id":"sub_001","comment_id":"cmt_001"}', 'pending', '2025-08-22 07:11:00');
