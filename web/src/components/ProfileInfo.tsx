import React, { useState, useRef, useEffect } from "react";

const LOGO_SIZE = 48;
const RING_SIZE = 56;
const RING_STROKE = 3;
const RING_R = (RING_SIZE - RING_STROKE) / 2;
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_R;

export interface ProfileInfoProps {
  /** When true, shows plus icon and "Invite your duo" (no player invited) */
  empty?: boolean;
  logoSrc?: string;
  name?: string;
  id?: number | string;
  level?: number;
  levelProgress?: number; // 0–1 progress to next level
  /** Called when user confirms invite with a value (e.g. player id or name) */
  onInviteSubmit?: (value: string) => void;
}

const ProfileInfo: React.FC<ProfileInfoProps> = ({
  empty = false,
  logoSrc = "",
  name = "",
  id = "",
  level = 0,
  levelProgress = 0,
  onInviteSubmit,
}) => {
  const [isEditing, setIsEditing] = useState(false);
  const [inputValue, setInputValue] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const ringOffset = RING_CIRCUMFERENCE * (1 - levelProgress);

  useEffect(() => {
    if (isEditing) {
      inputRef.current?.focus();
    } else {
      setInputValue("");
    }
  }, [isEditing]);

  const handleConfirm = () => {
    const trimmed = inputValue.trim();
    if (trimmed) onInviteSubmit?.(trimmed);
    setIsEditing(false);
    setInputValue("");
  };

  const handleCancel = () => {
    setIsEditing(false);
    setInputValue("");
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") handleConfirm();
    if (e.key === "Escape") handleCancel();
  };

  if (!empty) {
    return (
      <div className="group/profile flex flex-row gap-4 rounded-lg py-1 pr-2 -my-1 -mr-2 transition-colors duration-200">
        <div className="flex flex-col items-center gap-2">
          <div
            className="relative flex justify-center items-center transition-transform duration-200 hover:scale-105"
            style={{ width: RING_SIZE, height: RING_SIZE }}
          >
            <svg
              className="absolute inset-0 -rotate-90 transition-opacity duration-200 group-hover/profile:opacity-100 opacity-90"
              width={RING_SIZE}
              height={RING_SIZE}
              viewBox={`0 0 ${RING_SIZE} ${RING_SIZE}`}
              aria-hidden
            >
              <circle
                cx={RING_SIZE / 2}
                cy={RING_SIZE / 2}
                r={RING_R}
                fill="none"
                stroke="rgba(255,255,255,0.15)"
                strokeWidth={RING_STROKE}
              />
              <circle
                cx={RING_SIZE / 2}
                cy={RING_SIZE / 2}
                r={RING_R}
                fill="none"
                stroke="#8bff73"
                strokeWidth={RING_STROKE}
                strokeLinecap="round"
                strokeDasharray={RING_CIRCUMFERENCE}
                strokeDashoffset={ringOffset}
                className="transition-[stroke-dashoffset,filter] duration-300 group-hover/profile:drop-shadow-[0_0_6px_rgba(139,255,115,0.5)]"
              />
            </svg>
            <div
              className="w-12 h-12 rounded-full overflow-hidden shrink-0 flex justify-center items-center border border-[#8bff73] transition-all duration-200 hover:shadow-[0_0_14px_rgba(139,255,115,0.2)]"
              style={{ width: LOGO_SIZE, height: LOGO_SIZE, backgroundColor: logoSrc ? "white" : "#154a0a" }}
            >
              {logoSrc ? (
                <img
                  src={logoSrc}
                  alt=""
                  className="w-full h-full object-cover rounded-full transition-transform duration-200 group-hover/profile:scale-105"
                />
              ) : null}
            </div>
            <div className="absolute top-11 z-2 flex justify-center items-center bg-[#154a0a] w-5 h-5 rounded-full transition-transform duration-200 group-hover/profile:scale-110">
              <span
                className="text-[0.75rem] font-regular text-white tabular-nums"
                style={{ textShadow: "0 2px 4px rgba(0,0,0,1)" }}
              >
                {level}
              </span>
            </div>
          </div>
        </div>
        <div className="flex flex-col justify-center min-w-0">
          <h1 className="text-xl font-bold text-[#8bff73] transition-colors duration-200 group-hover/profile:text-[#a8ff8f]">
            {name}
          </h1>
          <p className="text-sm text-white mt-[-0.3rem] transition-opacity duration-200 group-hover/profile:opacity-90">
            ID: {id}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="group/profile rounded-lg py-1 pr-2 -my-1 -mr-2 transition-colors duration-200 min-h-[56px] relative">
      <div
        role="button"
        tabIndex={0}
        onClick={() => setIsEditing(true)}
        onKeyDown={(e) => e.key === "Enter" && setIsEditing(true)}
        className={`absolute inset-0 flex flex-row gap-4 items-center transition-all duration-300 ease-out origin-left group-hover/profile:scale-105 ${
          isEditing
            ? "opacity-0 pointer-events-none scale-95"
            : "opacity-100 pointer-events-auto scale-100"
        }`}
      >
        <div
          className="relative cursor-pointer flex justify-center items-center"
          style={{ width: RING_SIZE, height: RING_SIZE }}
        >
          <div
            className="w-12 h-12 rounded-full overflow-hidden shrink-0 flex justify-center items-center border border-[#8bff73] transition-all duration-200 hover:shadow-[0_0_14px_rgba(139,255,115,0.2)] hover:bg-white/10 hover:border-[#a8ff8f]"
            style={{ width: LOGO_SIZE, height: LOGO_SIZE, backgroundColor: "transparent" }}
          >
            <span className="text-2xl font-light text-[#8bff73] leading-none select-none">
              +
            </span>
          </div>
        </div>
        <div className="flex flex-col justify-center min-w-0">
          <h1 className="text-xl font-bold text-[#8bff73] transition-colors duration-200 group-hover/profile:text-[#a8ff8f] cursor-pointer">
            <span className="inline-block">
              Invite your duo
            </span>
          </h1>
        </div>
      </div>

      <div
        className={`absolute inset-0 flex flex-row items-center gap-2 transition-all duration-300 ease-out ${
          isEditing
            ? "opacity-100 pointer-events-auto scale-100"
            : "opacity-0 pointer-events-none scale-95"
        }`}
      >
        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Player ID or name..."
          className="flex-1 min-w-0 h-10 px-3 rounded-lg bg-[#1c1c1c] border border-[#8bff73]/50 text-white placeholder:text-white/50 focus:outline-none focus:border-[#8bff73] focus:ring-1 focus:ring-[#8bff73]/30 transition-colors duration-200 text-sm"
        />
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); handleConfirm(); }}
          aria-label="Confirm invite"
          className="cursor-pointer shrink-0 w-10 h-10 rounded-full flex items-center justify-center bg-[#154a0a] text-[#8bff73] hover:bg-[#1a5a12] hover:scale-105 active:scale-95 transition-all duration-200 border border-[#8bff73]/50"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </button>
        <button
          type="button"
          onClick={(e) => { e.stopPropagation(); handleCancel(); }}
          aria-label="Cancel"
          className="cursor-pointer shrink-0 w-10 h-10 rounded-full flex items-center justify-center bg-white/10 text-white/80 hover:bg-red-500/20 hover:text-red-400 border border-white/20 hover:border-red-400/50 transition-all duration-200 hover:scale-105 active:scale-95"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        </button>
      </div>
    </div>
  );
};

export default ProfileInfo;
