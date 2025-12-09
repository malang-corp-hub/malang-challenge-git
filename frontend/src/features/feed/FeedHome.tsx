// src/features/feed/FeedHome.tsx
import { Link } from "react-router-dom";

function FeedHome() {
  return (
    <div style={{ padding: 16 }}>
      <h1>FeedHome</h1>
      <p>여기가 2열 그리드 피드가 들어갈 메인 화면이야.</p>

      <Link to="/posts/1">테스트용 포스트 상세로 이동</Link>
    </div>
  );
}

export default FeedHome;