import type { Metadata } from "next";
import { Nunito } from "next/font/google";
import "./globals.css";

const nunito = Nunito({ variable: "--font-nunito", subsets: ["latin"], weight: ["400", "600", "700", "800", "900"] });

export const metadata: Metadata = {
  title: "Rumbo Rehab · Fisioterapeuta",
  description: "Seguimiento del apego terapéutico en casa, verificado por el reloj.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body className={`${nunito.variable} antialiased`}>{children}</body>
    </html>
  );
}
