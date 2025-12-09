// src/App.tsx
import { Routes, Route } from "react-router-dom";
import MainTabLayout from "./layout/MainTabLayout";

// Feed
import FeedHome from "./features/feed/FeedHome";
import PostDetail from "./features/feed/PostDetail";

// Store
import StoreEntry from "./features/store/StoreEntry";

// MyPage
import MyProfile from "./features/mypage/MyProfile";

function App() {
  return (
    <Routes>
      {/* ⭐ 전체 화면에 공통 레이아웃(MainTabLayout) 적용 */}
      <Route element={<MainTabLayout />}>
        {/* 메인 피드 */}
        <Route path="/" element={<FeedHome />} />

        {/* 포스트 상세 */}
        <Route path="/posts/:id" element={<PostDetail />} />

        {/* 스토어 탭 (외부링크 대신 현재는 화면용) */}
        <Route path="/store" element={<StoreEntry />} />

        {/* 마이페이지 */}
        <Route path="/mypage" element={<MyProfile />} />
      </Route>
    </Routes>
  );
}

export default App;
