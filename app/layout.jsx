import "./globals.css";
export const metadata = {
  title: "Money Flow Agency | MFA",
  description: "A connected network for money-flow agents, transfers and payment services."
};
export default function RootLayout({ children }) {
  return <html lang="en"><body>{children}</body></html>;
}