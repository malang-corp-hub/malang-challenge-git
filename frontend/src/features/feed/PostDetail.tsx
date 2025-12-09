// src/features/feed/PostDetail.tsx
import { useParams } from "react-router-dom";

function PostDetail() {
  const { id } = useParams<{ id: string }>();

  return (
    <div style={{ padding: 16 }}>
      <h1>PostDetail</h1>
      <p>여기가 포스트 상세 화면이야.</p>
      <p>현재 포스트 ID: {id}</p>
    </div>
  );
}

export default PostDetail;
