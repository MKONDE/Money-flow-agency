"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import "./site-header.module.css";

const links = [
  ["About", "/about"],
  ["Services", "/services"],
  ["Find an Agent", "/agents"],
  ["Track request", "/transactions"],
  ["Partners", "/partners"],
];

export function SiteHeader() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="site-header">
      <div className="container nav-wrap">
        <Link href="/" className="brand" aria-label="Money Flow Agency home" onClick={() => setMenuOpen(false)}>
          <Image src="/mfa-logo.svg" alt="Money Flow Agency" width={62} height={62} priority />
        </Link>
        <nav className="desktop-nav" aria-label="Main navigation">
          {links.map(([label, href]) => <Link href={href} key={href}>{label}</Link>)}
        </nav>
        <div className="nav-actions">
          <Link className="login-link" href="/login">Agent login</Link>
          <Link className="button button-small join-network" href="/become-agent">Join network <span aria-hidden="true">↗</span></Link>
          <button className="mobile-menu-toggle" type="button" aria-label={menuOpen ? "Close navigation menu" : "Open navigation menu"} aria-expanded={menuOpen} aria-controls="mobile-primary-navigation" onClick={() => setMenuOpen((open) => !open)}>
            <span aria-hidden="true">{menuOpen ? "×" : "☰"}</span>
          </button>
        </div>
      </div>
      <nav id="mobile-primary-navigation" className={`mobile-nav${menuOpen ? " is-open" : ""}`} aria-label="Mobile navigation" aria-hidden={!menuOpen}>
        {links.map(([label, href]) => <Link href={href} key={href} tabIndex={menuOpen ? 0 : -1} onClick={() => setMenuOpen(false)}>{label}</Link>)}
        <Link href="/login" tabIndex={menuOpen ? 0 : -1} onClick={() => setMenuOpen(false)}>Agent login</Link>
      </nav>
    </header>
  );
}
