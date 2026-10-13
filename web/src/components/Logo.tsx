/** Logotipo de Rumbo Rehab (identidad-marca §2.2 y §8.1): isotipo + "rumbo" + "REHAB". */
export function Isotipo({ size = 40 }: { size?: number }) {
  return (
    <svg viewBox="0 0 48 48" width={size} height={size} aria-hidden="true">
      <g fill="#3F3A9E">
        <circle cx="8" cy="42" r="2.5" />
        <circle cx="12.3" cy="35.2" r="2.5" />
        <circle cx="20.3" cy="32.3" r="2.5" />
        <circle cx="27.3" cy="27.8" r="2.5" />
      </g>
      <path d="M27.5 10 Q36 28 44.5 10" fill="none" stroke="#F2B33D" strokeWidth="4.5" strokeLinecap="round" />
      <circle cx="36" cy="9" r="4.5" fill="#F2B33D" />
    </svg>
  );
}

export function Logo({ size = 30 }: { size?: number }) {
  return (
    <div className="flex items-center" style={{ gap: size * 0.25 }} aria-label="Rumbo Rehab">
      <Isotipo size={size * 1.45} />
      <div className="flex flex-col" style={{ gap: size * 0.1 }}>
        <span className="font-black leading-[0.9] text-primary" style={{ fontSize: size, letterSpacing: "-0.02em" }}>
          rumbo
        </span>
        <span className="font-extrabold leading-none text-muted" style={{ fontSize: size * 0.26, letterSpacing: "0.42em" }}>
          REHAB
        </span>
      </div>
    </div>
  );
}
