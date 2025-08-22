# Malang Challenge DB Schema

이 저장소는 **Malang Challenge** 서비스에서 사용하는 데이터베이스 스키마를 관리합니다.  
현재는 **SQLite** 를 기준으로 빠른 실습/테스트를 하며, 추후 **PostgreSQL** 또는 **Firebase Firestore 구조**에도 확장할 수 있습니다.

---

## 📂 파일 구조
- `schema_v1.sql`  
  데이터베이스 스키마 정의서 (DDL).  
  - `users` : 사용자 계정 / 프로필
  - `challenges` : 챌린지 정보
  - `submissions` : 출품작
  - `likes` : 좋아요(투표)
  - `comments` : 댓글
  - `reports` : 신고
  - `notifications` : 알림  

- `README.md`  
  저장소 소개 및 사용 방법

---

## 🚀 사용 방법

### 1) SQLite로 테스트
```bash
# 데이터베이스 파일 생성 및 스키마 적용
sqlite3 mydb.db < schema_v1.sql

# DB 접속
sqlite3 mydb.db

# 테이블 확인
```sql
.tables

# 샘플 데이터 추가
INSERT INTO users (id, naver_id, name)
VALUES ('u1', 'naver123', '홍길동');

SELECT * FROM users;