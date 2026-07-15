import React, { useState, useEffect } from "react";
import "./App.css";
import { debugData } from "../utils/debugData";
import { fetchNui } from "../utils/fetchNui";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { useVisibility } from "../providers/VisibilityProvider";
import ProfileInfo from "./ProfileInfo";
import logo from "../assets/user.png";

debugData([{ action: "setVisible", data: true }]);

const POSTMAN_ZONES = [
  { id: "los_santos", name: "Los Santos", description: "Urban mail routes through downtown neighborhoods and business districts." },
  { id: "sandy_shores", name: "Sandy Shores", description: "Desert trail deliveries to trailers, motels, and lakeside cabins." },
  { id: "paleto_bay", name: "Paleto Bay", description: "Northern coastal and mountain mail runs for remote residents." },
] as const;

const BASE_JOBS: Record<string, { id: number; column: string; name: string; description: string; accent: string }[]> = {
  los_santos: [
    { id: 1, column: "1", accent: "#8bff73", name: "Vinewood Letters", description: "Mailbox drops, door knocks, and cluster boxes across quiet residential blocks." },
    { id: 2, column: "2", accent: "#72e05a", name: "Davis Express", description: "Newspaper tosses, registered signatures, and heavy packages on a tight schedule." },
    { id: 3, column: "3", accent: "#5cc743", name: "Port City Priority", description: "Dog-yard deliveries and priority registered mail through busy industrial streets." },
  ],
  sandy_shores: [
    { id: 4, column: "1", accent: "#a8ff8f", name: "Trailer Trail", description: "Dusty mailbox runs and porch newspaper tosses around Sandy Shores main drag." },
    { id: 5, column: "2", accent: "#8bff73", name: "Alamo Circuit", description: "Lake-side door knocks and cluster deliveries to scattered desert homes." },
    { id: 6, column: "3", accent: "#72e05a", name: "Harmony Haul", description: "Heavy packages and registered mail to the farthest desert outposts." },
  ],
  paleto_bay: [
    { id: 7, column: "1", accent: "#8bff73", name: "Town Center Route", description: "Classic mailbox and newspaper loops through Paleto's main street." },
    { id: 8, column: "2", accent: "#6ed456", name: "Forest Lane", description: "Door-to-door knocks and dog-yard stops on winding mountain roads." },
    { id: 9, column: "3", accent: "#4ab832", name: "North Coast Express", description: "Premium registered packages to the most remote northern properties." },
  ],
};

interface PlayerData {
  playerName: string;
  playerId: number;
  playerLevel: number;
  currentXP: number;
  maxXP: number;
}

interface InvitedPlayer { name: string; id: number; }
interface MissionReward { reward: number; xpReward: number; }

const App: React.FC = () => {
  const [playerData, setPlayerData] = useState<PlayerData>({
    playerName: "Loading...", playerId: 0, playerLevel: 1, currentXP: 0, maxXP: 100,
  });
  const [invitedPlayer, setInvitedPlayer] = useState<InvitedPlayer | null>(null);
  const [activeTransportIndex, setActiveTransportIndex] = useState<number | null>(0);
  const [missionRewards, setMissionRewards] = useState<Record<string, MissionReward>>({});
  const [xpMultiplier, setXpMultiplier] = useState(1.0);
  const [moneyMultiplier, setMoneyMultiplier] = useState(1.0);
  const [isInMission, setIsInMission] = useState(false);
  const [currentMissionId, setCurrentMissionId] = useState("");
  const [currentMissionColumn, setCurrentMissionColumn] = useState("");
  const [missionError, setMissionError] = useState<string | null>(null);
  const [isInvitee, setIsInvitee] = useState(false);
  const [isGroupInvitee, setIsGroupInvitee] = useState(false);
  const [hoveredJobId, setHoveredJobId] = useState<number | null>(null);
  const [startingMission, setStartingMission] = useState<{ categoryId: string; column: string } | null>(null);
  const { visible } = useVisibility();

  useNuiEvent<PlayerData>("setPlayerData", (data) => {
    setPlayerData(prev => ({ ...prev, playerName: data.playerName, playerId: data.playerId }));
  });

  useNuiEvent<InvitedPlayer | null>("updateInvitedPlayer", setInvitedPlayer);

  useNuiEvent<{ xpMultiplier: number; moneyMultiplier: number }>("setMultipliers", (data) => {
    setXpMultiplier(data.xpMultiplier);
    setMoneyMultiplier(data.moneyMultiplier);
  });

  useNuiEvent<{ level: number; exp: number; expnextlevel: number }>("updatePlayerLevel", (data) => {
    setPlayerData(prev => ({ ...prev, playerLevel: data.level || 1, currentXP: data.exp || 0, maxXP: data.expnextlevel || 100 }));
  });

  useNuiEvent<{ level: number; exp: number; expnextlevel: number }>("updateLevel", (data) => {
    setPlayerData(prev => ({ ...prev, playerLevel: data.level || 1, currentXP: data.exp || 0, maxXP: data.expnextlevel || 100 }));
  });

  useNuiEvent<{ message: string }>("missionError", (data) => {
    setMissionError(data.message);
    setStartingMission(null);
    setTimeout(() => setMissionError(null), 3000);
  });

  useNuiEvent<{ inMission: boolean; currentMissionId: string; currentMissionColumn: string; isInvitee?: boolean; isGroupInvitee?: boolean }>("missionStatusChanged", (data) => {
    setIsInMission(data.inMission);
    setCurrentMissionId(data.currentMissionId || "");
    setCurrentMissionColumn(data.currentMissionColumn || "");
    setIsInvitee(data.isInvitee || false);
    setIsGroupInvitee(data.isGroupInvitee || false);
    setStartingMission(null);
  });

  useEffect(() => {
    if (!visible) return;
    setStartingMission(null);

    fetchNui<{ level: number; exp: number; expnextlevel: number }>("GetPlayerLevel", {}, { level: 1, exp: 50, expnextlevel: 200 })
      .then((data) => setPlayerData(prev => ({ ...prev, playerLevel: data.level || 1, currentXP: data.exp || 0, maxXP: data.expnextlevel || 100 })))
      .catch(console.error);

    fetchNui<{ xpMultiplier: number; moneyMultiplier: number }>("GetMultipliers", {}, { xpMultiplier: 1.0, moneyMultiplier: 1.0 })
      .then((data) => { setXpMultiplier(data.xpMultiplier || 1.0); setMoneyMultiplier(data.moneyMultiplier || 1.0); })
      .catch(console.error);

    fetchNui<{ inMission: boolean; currentMissionId: string; currentMissionColumn: string; isInvitee?: boolean; isGroupInvitee?: boolean }>("IsInMission", {}, {
      inMission: false, currentMissionId: "", currentMissionColumn: "", isInvitee: false, isGroupInvitee: false,
    }).then((data) => {
      setIsInMission(data.inMission || false);
      setCurrentMissionId(data.currentMissionId || "");
      setCurrentMissionColumn(data.currentMissionColumn || "");
      setIsInvitee(data.isInvitee || false);
      setIsGroupInvitee(data.isGroupInvitee || false);
    }).catch(console.error);
  }, [visible]);

  useEffect(() => {
    if (activeTransportIndex === null) return;
    const category = POSTMAN_ZONES[activeTransportIndex];
    BASE_JOBS[category.id].forEach((job) => {
      const key = `${category.id}_${job.column}`;
      fetchNui<{ reward: number; xpReward: number }>("GetMissionReward", { column: job.column, selectedId: category.id }, { reward: 8500, xpReward: 50 })
        .then((data) => setMissionRewards(prev => ({ ...prev, [key]: { reward: data.reward || 8500, xpReward: data.xpReward || 50 } })))
        .catch(console.error);
    });
  }, [activeTransportIndex]);

  const handleStartMission = (categoryId: string, column: string) => {
    setStartingMission({ categoryId, column });
    const timeoutId = setTimeout(() => setStartingMission(null), 5000);
    fetchNui<{ success?: boolean }>("MissionStarted", { column, selectedId: categoryId }, { success: false })
      .then((response) => { clearTimeout(timeoutId); if (response?.success === false) setStartingMission(null); })
      .catch(() => { clearTimeout(timeoutId); setStartingMission(null); });
  };

  const handleStopMission = () => {
    fetchNui("ResetMy", {}).then(() => {
      setIsInMission(false);
      setCurrentMissionId("");
      setCurrentMissionColumn("");
    }).catch(console.error);
  };

  const levelProgress = playerData.maxXP > 0 ? playerData.currentXP / playerData.maxXP : 0;
  const currentCategory = activeTransportIndex !== null ? POSTMAN_ZONES[activeTransportIndex] : null;
  const currentJobs = currentCategory ? BASE_JOBS[currentCategory.id] : [];

  return (
    <div className="absolute bg-black/90 rounded-lg w-[75rem] h-[43rem] top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 flex flex-row overflow-hidden">
      <div className="left-panel flex flex-col w-[25%] p-5 bg-[#0f100f] h-full">
        <ProfileInfo
          logoSrc={logo}
          name={playerData.playerName}
          id={playerData.playerId}
          level={playerData.playerLevel}
          levelProgress={levelProgress}
        />
        <div className="panel h-[2px] mt-3 mb-3"></div>
        {invitedPlayer ? (
          <ProfileInfo logoSrc={logo} name={invitedPlayer.name} id={invitedPlayer.id} level={1} levelProgress={0} />
        ) : (
          <ProfileInfo empty onInviteSubmit={(v) => { const id = parseInt(v); if (!isNaN(id)) fetchNui("invite", { targetId: id }).catch(console.error); }} />
        )}

        <div className="left-panel__section-title">Select Zone</div>
        <div className="transport-cards-container">
          {POSTMAN_ZONES.map((category, index) => (
            <div
              key={category.id}
              role="button"
              tabIndex={0}
              onClick={() => setActiveTransportIndex(i => i === index ? null : index)}
              className={`transport-card ${activeTransportIndex === index ? "active" : ""}`}
            >
              <div className="transport-card__accent" />
              <div className="transport-card__icon">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M1.5 8.67v8.58a3 3 0 0 0 3 3h15a3 3 0 0 0 3-3V8.67l-8.928 5.493a3 3 0 0 1-3.144 0L1.5 8.67Z" />
                  <path d="M22.5 6.908V6.75a3 3 0 0 0-3-3h-15a3 3 0 0 0-3 3v.158l9.714 5.978a1.5 1.5 0 0 0 1.572 0L22.5 6.908Z" />
                </svg>
              </div>
              <div className="transport-card__content">
                <div className="transport-card__title">{category.name}</div>
                <div className="transport-card__desc">{category.description}</div>
              </div>
              <div className="transport-card__arrow">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M8.22 5.22a.75.75 0 0 1 1.06 0l4.25 4.25a.75.75 0 0 1 0 1.06l-4.25 4.25a.75.75 0 0 1-1.06-1.06L11.94 10 8.22 6.28a.75.75 0 0 1 0-1.06Z" clipRule="evenodd" />
                </svg>
              </div>
            </div>
          ))}
        </div>

        <div className="multipliers-container">
          <div className="multiplier-card multiplier-card--xp">
            <div className="multiplier-card__icon">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
                <path fillRule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.006 5.404.434c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.434 2.082-5.005Z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="multiplier-card__content">
              <div className="multiplier-card__label">XP Boost</div>
              <div className="multiplier-card__value">{xpMultiplier.toFixed(1)}x</div>
            </div>
          </div>
          <div className="multiplier-card multiplier-card--money">
            <div className="multiplier-card__icon">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 7.5a2.25 2.25 0 1 0 0 4.5 2.25 2.25 0 0 0 0-4.5Z" />
                <path fillRule="evenodd" d="M1.5 4.875C1.5 3.839 2.34 3 3.375 3h17.25c1.035 0 1.875.84 1.875 1.875v9.75c0 1.036-.84 1.875-1.875 1.875H3.375A1.875 1.875 0 0 1 1.5 14.625v-9.75ZM8.25 9.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM18.75 9a.75.75 0 0 0-.75.75v.008c0 .414.336.75.75.75h.008a.75.75 0 0 0 .75-.75V9.75a.75.75 0 0 0-.75-.75h-.008ZM4.5 9.75A.75.75 0 0 1 5.25 9h.008a.75.75 0 0 1 .75.75v.008a.75.75 0 0 1-.75.75H5.25a.75.75 0 0 1-.75-.75V9.75Z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="multiplier-card__content">
              <div className="multiplier-card__label">Cash Boost</div>
              <div className="multiplier-card__value">{moneyMultiplier.toFixed(1)}x</div>
            </div>
          </div>
        </div>
      </div>

      <div className="jobs-panel">
        {missionError && <div className="mission-error-notification">{missionError}</div>}
        {currentCategory && (
          <div className="jobs-panel__header">
            <h2 className="jobs-panel__title">{currentCategory.name}</h2>
            <p className="jobs-panel__subtitle">{currentCategory.description}</p>
          </div>
        )}

        {currentJobs.length === 0 ? (
          <div className="jobs-panel__empty">
            <div className="jobs-panel__empty-icon">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" />
              </svg>
            </div>
            <p className="jobs-panel__empty-text">Select a zone to view mail routes</p>
          </div>
        ) : (
          <div className="jobs-grid">
            {currentJobs.map((job) => {
              const rewardKey = `${currentCategory?.id}_${job.column}`;
              const rewards = missionRewards[rewardKey] || { reward: 8500, xpReward: 50 };
              const isThisMission = isInMission && currentMissionId === currentCategory?.id && currentMissionColumn === job.column;
              const isInDifferentMission = isInMission && !isThisMission;
              const isHovered = hoveredJobId === job.id;
              const isStartingThis = startingMission?.categoryId === currentCategory?.id && startingMission?.column === job.column;
              const isStartingDifferent = startingMission !== null && !isStartingThis;

              let buttonLabel = "START ROUTE";
              let buttonClass = "mission-card__button";
              let clickHandler = () => currentCategory && handleStartMission(currentCategory.id, job.column);

              if (isGroupInvitee && !isInMission) {
                buttonLabel = "WAITING FOR LEADER";
                buttonClass += " mission-card__button--disabled";
                clickHandler = () => {};
              } else if (isStartingThis) {
                buttonLabel = "LOADING...";
                buttonClass += " mission-card__button--starting";
                clickHandler = () => {};
              } else if (isThisMission) {
                if (isInvitee) {
                  buttonLabel = "IN PROGRESS";
                  buttonClass += " mission-card__button--active";
                  clickHandler = () => {};
                } else {
                  buttonLabel = isHovered ? "STOP ROUTE" : "IN PROGRESS";
                  buttonClass += isHovered ? " mission-card__button--stop" : " mission-card__button--active";
                  clickHandler = handleStopMission;
                }
              } else if (isInDifferentMission || isStartingDifferent) {
                buttonLabel = isStartingDifferent ? "LOADING..." : "UNAVAILABLE";
                buttonClass += " mission-card__button--disabled";
                clickHandler = () => {};
              }

              return (
                <article
                  key={job.id}
                  className={`mission-card ${isThisMission ? "mission-card--active" : ""} ${isInDifferentMission || isStartingDifferent ? "mission-card--disabled" : ""} ${isStartingThis ? "mission-card--starting" : ""}`}
                  onMouseEnter={() => setHoveredJobId(job.id)}
                  onMouseLeave={() => setHoveredJobId(null)}
                >
                  <div className="mission-card__image" style={{ background: `linear-gradient(135deg, ${job.accent}88, #0f100f)` }}>
                    <div className="mission-card__image-overlay" />
                    <div className="mission-card__badge"><span>#{job.column}</span></div>
                    {isThisMission && (
                      <div className="mission-card__status">
                        <span className="mission-card__status-dot" />
                        <span>Active</span>
                      </div>
                    )}
                  </div>
                  <div className="mission-card__content">
                    <h3 className="mission-card__title">{job.name}</h3>
                    <p className="mission-card__description">{job.description}</p>
                    <div className="mission-card__rewards">
                      <div className="mission-card__reward">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="mission-card__reward-icon mission-card__reward-icon--money">
                          <path d="M12 7.5a2.25 2.25 0 1 0 0 4.5 2.25 2.25 0 0 0 0-4.5Z" />
                          <path fillRule="evenodd" d="M1.5 4.875C1.5 3.839 2.34 3 3.375 3h17.25c1.035 0 1.875.84 1.875 1.875v9.75c0 1.036-.84 1.875-1.875 1.875H3.375A1.875 1.875 0 0 1 1.5 14.625v-9.75ZM8.25 9.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM18.75 9a.75.75 0 0 0-.75.75v.008c0 .414.336.75.75.75h.008a.75.75 0 0 0 .75-.75V9.75a.75.75 0 0 0-.75-.75h-.008ZM4.5 9.75A.75.75 0 0 1 5.25 9h.008a.75.75 0 0 1 .75.75v.008a.75.75 0 0 1-.75.75H5.25a.75.75 0 0 1-.75-.75V9.75Z" clipRule="evenodd" />
                        </svg>
                        <span className="mission-card__reward-value">${rewards.reward.toLocaleString()}</span>
                      </div>
                      <div className="mission-card__reward">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="mission-card__reward-icon mission-card__reward-icon--xp">
                          <path fillRule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.006 5.404.434c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.434 2.082-5.005Z" clipRule="evenodd" />
                        </svg>
                        <span className="mission-card__reward-value">+{rewards.xpReward} XP</span>
                      </div>
                    </div>
                  </div>
                  <div
                    className={buttonClass}
                    role="button"
                    tabIndex={0}
                    onClick={clickHandler}
                    onKeyDown={(e) => e.key === "Enter" && clickHandler()}
                  >
                    <span className="mission-card__button-label">{buttonLabel}</span>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default App;
