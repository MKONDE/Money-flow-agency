import Link from "next/link";

const pillars = [
  { number: "01", title: "Agent Network", body: "Discover independent agents by location, language, service and verification status." },
  { number: "02", title: "Business Services", body: "Connect marketplaces, agricultural businesses and service providers to local support." },
  { number: "03", title: "Partner Integrations", body: "Work with multiple business partners through scoped, secure integrations." },
];
const steps = [
  ["Apply", "Create an individual or business agent profile."],
  ["Get reviewed", "The MFA team checks the application and supporting information."],
  ["Build your presence", "Approved agents can publish their profile and approved services."],
];

export default function HomePage() {
  return (
    <>
      <section className="hero">
        <div className="hero-glow" />
        <div className="container hero-grid">
          <div className="hero-copy">
            <div className="eyebrow"><span className="eyebrow-dot" /> INDEPENDENT GLOBAL AGENT NETWORK</div>
            <h1>Local trust.<br /><em>Global reach.</em></h1>
            <p className="hero-lead">A professional network connecting verified agents, growing businesses and service partners — across markets and communities.</p>
            <div className="hero-actions">
              <Link className="button" href="/become-agent">Become an agent <span aria-hidden="true">↗</span></Link>
              <Link className="button button-ghost" href="/agents">Explore agent network <span aria-hidden="true">→</span></Link>
            </div>
            <div className="hero-proof"><span className="proof-check">✓</span> Independent platform <span className="proof-separator">·</span> Multi-partner by design</div>
          </div>
          <div className="hero-visual" aria-label="Illustration of connected agent network">
            <div className="orbit orbit-one" /><div className="orbit orbit-two" />
            <div className="network-core"><span className="core-mark">M</span><strong>MFA</strong><small>AGENT NETWORK</small></div>
            <div className="network-node node-a"><span>◎</span><small>Agents</small></div>
            <div className="network-node node-b"><span>⌂</span><small>Businesses</small></div>
            <div className="network-node node-c"><span>↗</span><small>Partners</small></div>
            <div className="network-node node-d"><span>◇</span><small>Customers</small></div>
            <div className="visual-caption"><span className="live-dot" /> ONE NETWORK. MANY PARTNERS.</div>
          </div>
        </div>
        <div className="container hero-bottom"><span>BUILT FOR INDEPENDENT BUSINESSES</span><span className="hero-bottom-line" /><span>AGENTS · PARTNERS · COMMUNITIES</span></div>
      </section>

      <section className="section section-intro">
        <div className="container intro-grid">
          <div><div className="section-kicker">WHAT WE DO</div><h2>We make trusted<br />connections <em>work.</em></h2></div>
          <div className="intro-text"><p>Money Flow Agency builds and manages an independent agent network that supports businesses and customers with agent discovery, service assistance, partner coordination and traceable service references.</p><Link className="text-link" href="/about">Learn about MFA <span>→</span></Link></div>
        </div>
      </section>

      <section className="section section-pale">
        <div className="container">
          <div className="section-heading"><div><div className="section-kicker">THE MFA PLATFORM</div><h2>One network.<br /><em>More possibilities.</em></h2></div><p>Designed to support multiple partners without mixing their systems, records or responsibilities.</p></div>
          <div className="pillar-grid">{pillars.map((item) => <article className="pillar-card" key={item.number}><span className="pillar-number">{item.number}</span><div className="pillar-icon">{item.number === "01" ? "◎" : item.number === "02" ? "⌂" : "↗"}</div><h3>{item.title}</h3><p>{item.body}</p><span className="card-arrow">↗</span></article>)}</div>
        </div>
      </section>

      <section className="section">
        <div className="container journey-grid">
          <div><div className="section-kicker">JOIN THE NETWORK</div><h2>Your next step<br />starts <em>here.</em></h2><p className="journey-copy">Apply to become part of a growing network of independent agents and service businesses.</p><Link className="button" href="/become-agent">Start your application <span>↗</span></Link></div>
          <div className="steps-list">{steps.map(([title, body], index) => <div className="step" key={title}><span className="step-number">0{index + 1}</span><div><h3>{title}</h3><p>{body}</p></div><span className="step-line" /></div>)}</div>
        </div>
      </section>

      <section className="partner-band"><div className="container partner-band-inner"><div><div className="section-kicker">BUILT FOR MANY PARTNERS</div><h2>Independent by nature.<br /><em>Connected by design.</em></h2></div><div><p>Cashflow Gate is one strategic partner among many. MFA maintains its own agent network, records, access controls and operating environment.</p><Link className="text-link text-link-light" href="/partners">Explore partnership opportunities <span>→</span></Link></div></div></section>

      <section className="section final-cta"><div className="container final-cta-inner"><div><div className="section-kicker">START WITH MFA</div><h2>Build your place<br />in the <em>network.</em></h2></div><div><p>Whether you are an agent, a business or a potential partner, there is a place to begin.</p><Link className="button" href="/contact">Talk to our team <span>↗</span></Link></div></div></section>
    </>
  );
}
