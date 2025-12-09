// src/features/store/StoreEntry.tsx
function StoreEntry() {
  const handleOpenStore = () => {
    window.open("https://smartstore.naver.com/kyoomalang", "_blank");
  };

  return (
    <div
      style={{
        height: "100%",
        padding: 16,
        display: "flex",
        flexDirection: "column",
        gap: 16,
        alignItems: "center",
        justifyContent: "center",
        textAlign: "center",
      }}
    >
      <p>
        스토어로 이동합니다.
        <br />
        외부 브라우저가 열릴 수 있어요.
      </p>
      <button onClick={handleOpenStore}>스마트스토어 열기</button>
    </div>
  );
}

export default StoreEntry;