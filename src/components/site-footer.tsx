import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="container footer-grid">
        <div>
          <Link href="/" className="brand footer-brand">
            <span className="brand-mark">M</span>
            <span className="brand-copy"><strong>MONEY FLOW</strong><small>AGENCY</small></span>
          </Link>
          <p className="footer-note">An independent agent network and business services platform built for trusted connections.</p>
        </div>
        <div><strong>Explore</strong><Link href="/agents">Find an agent</Link><Link href="/services">Our services</Link><Link href="/partners">Business partners</Link></div>
        <div><strong>Support</strong><Link href="/help">Help & complaints</Link><Link href="/contact">Contact</Link><Link href="/advertising">Advertising</Link></div>
        <div><strong>Legal</strong><Link href="/privacy">Privacy</Link><Link href="/terms">Terms & compliance</Link></div>
      </div>
      <div className="container footer-bottom"><span>© {new Date().getFullYear()} Money Flow Agency.</span><span>Independent platform · Partner data stays separate</span></div>
    </footer>
  );
}
