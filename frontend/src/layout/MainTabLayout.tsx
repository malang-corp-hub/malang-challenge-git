// src/layout/MainTabLayout.tsx
import { NavLink, Outlet, useLocation } from "react-router-dom";

const tabs = [
  { to: "/", label: "피드" },
  { to: "/store", label: "스토어" },
  { to: "/mypage", label: "마이페이지" },
];

function MainTabLayout() {
  const location = useLocation();

  return (
    <div className="flex h-screen flex-col md:flex-row">
      {/* ✅ PC 전용: 좌측 사이드 메뉴 */}
      <aside className="hidden md:flex w-48 border-r bg-white flex-col">
        {tabs.map((tab) => {
          const isActive =
            tab.to === "/"
              ? location.pathname === "/"
              : location.pathname.startsWith(tab.to);

          return (
            <NavLink
              key={tab.to}
              to={tab.to}
              className={`h-12 flex items-center justify-center text-sm ${
                isActive ? "font-bold" : "text-gray-500"
              }`}
            >
              {tab.label}
            </NavLink>
          );
        })}
      </aside>

      {/* ✅ 메인 컨텐츠 영역 */}
      <main className="flex-1 overflow-auto bg-neutral-50">
        <Outlet />
      </main>

      {/* ✅ 모바일 전용: 하단 탭바 */}
      <nav className="md:hidden h-14 border-t bg-white flex">
        {tabs.map((tab) => {
          const isActive =
            tab.to === "/"
              ? location.pathname === "/"
              : location.pathname.startsWith(tab.to);

          return (
            <NavLink
              key={tab.to}
              to={tab.to}
              className={`flex-1 flex items-center justify-center text-sm ${
                isActive ? "font-bold" : "text-gray-500"
              }`}
            >
              {tab.label}
            </NavLink>
          );
        })}
      </nav>
    </div>
  );
}

export default MainTabLayout;