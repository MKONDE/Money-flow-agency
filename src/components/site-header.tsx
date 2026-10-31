import Link from "next/link";

const links = [
  ["About", "/about"],
  ["Services", "/services"],
  ["Find an Agent", "/agents"],
  ["Partners", "/partners"],
];

export function SiteHeader() {
  return (
    <header className="site-header">
      <div className="container nav-wrap">
        <Link href="/" className="brand" aria-label="Money Flow Agency home">
          <span className="brand-mark">M</span>
          <span className="brand-copy"><strong>MONEY FLOW</strong><small>AGENCY</small></span>
        </Link>
        <nav className="desktop-nav" aria-label="Main navigation">
          {links.map(([label, href]) => <Link href={href} key={href}>{label}</Link>)}
        </nav>
        <div className="nav-actions">
          <Link className="login-link" href="/login">Agent login</Link>
          <Link className="button button-small" href="/become-agent">Join network <span aria-hidden="true">↗</span></Link>
        </div>
      </div>
    </header>
  );
}
