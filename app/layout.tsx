import type { Metadata } from 'next';
import Link from 'next/link';
import './globals.css';
export const metadata: Metadata = { title: 'Tông Môn — Member Nexus', description: 'Cổng thành viên Tông Môn — Minecraft × Discord' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
 return <html lang="vi"><body><header className="topbar"><div className="wrap nav"><Link className="brand" href="/">✦ TÔNG <b>MÔN</b></Link><nav className="navlinks"><Link href="/members">Thành viên</Link><Link href="/admin">Quản trị</Link><Link className="btn small" href="/login">Đăng nhập ↗</Link></nav></div></header>{children}<footer className="footer"><div className="wrap">✦ TÔNG MÔN — MEMBER NEXUS · Minecraft × Discord</div></footer></body></html>
}
