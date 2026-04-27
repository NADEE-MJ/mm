import Sidebar from "./Sidebar";

import type { ReactNode } from "react";

export default function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <main className="mx-auto w-full max-w-[1400px] px-4 pb-8 pt-4 min-[1280px]:px-6">{children}</main>
    </div>
  );
}
