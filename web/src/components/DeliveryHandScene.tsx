import { useEffect, useMemo, useRef, useState } from "react";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";
import boxImg from "../assets/box.png";
import envelopeImg from "../assets/envelop.png";
import avatarImg from "../assets/user.png";
import {
  createDeliveryItemsScene,
  DEFAULT_DELIVERY_MAIL,
  getDeliveryItemShape,
  type DeliveryItemShape,
  type DeliveryMailItem,
} from "../three/deliveryHandScene";
import "./DeliveryHandScene.css";

interface OpenDeliveryHandPayload {
  items?: DeliveryMailItem[];
  regionName?: string;
  agentName?: string;
}

const devPreviewEnabled =
  import.meta.env.DEV &&
  new URLSearchParams(window.location.search).has("deliveryHand");

const STOP_TYPE_LABELS: Record<string, string> = {
  mailbox: "Mailbox",
  door_knock: "Door knock",
  package: "Heavy package",
  cluster: "Regular",
  registered: "Registered mail",
  newspaper: "Newspaper toss",
  dog_yard: "Dog yard",
};

const ITEM_SHAPE_LABELS: Record<string, string> = {
  mailbox: "Envelope",
  door_knock: "Envelope",
  package: "Package box",
  cluster: "Regular",
  registered: "Envelope",
  newspaper: "Newspaper roll",
  dog_yard: "Envelope",
};

const CARD_SHAPE_IMAGES: Record<DeliveryItemShape, string> = {
  envelope: envelopeImg,
  box: boxImg,
  newspaper: envelopeImg,
};

const getCardShapeImage = (item: DeliveryMailItem) =>
  CARD_SHAPE_IMAGES[getDeliveryItemShape(item.stopType, item.noteType)];

const getItemShapeLabel = (item: DeliveryMailItem) =>
  ITEM_SHAPE_LABELS[item.stopType] ?? "Delivery item";

const INSTRUCTIONS_BY_STOP_TYPE: Record<string, string> = {
  mailbox: "Deposit in mailbox.",
  door_knock: "Knock before delivering.",
  package: "Handle with care. Leave at front door.",
  cluster: "Deliver all items at this stop.",
  registered: "Signature required. Deliver to recipient only.",
  newspaper: "Toss newspaper onto porch.",
  dog_yard: "Watch for dog in yard. Knock before entering gate.",
};

const DEMO_RECIPIENTS = ["M. Santos", "L. Johnson", "R. De Santa", "T. Clinton", "Porch delivery"];

const getDeliveryDetails = (item: DeliveryMailItem | null) => {
  if (!item) {
    return {
      status: "—",
      adresse: "—",
      reciepent: "—",
      tracking: "—",
      instructions: "Select a destination on the left.",
    };
  }

  const stopIndex = "ABCDE".indexOf(item.label.toUpperCase());

  return {
    status: item.note,
    adresse: item.address,
    reciepent: item.recipient ?? DEMO_RECIPIENTS[stopIndex] ?? "Resident",
    tracking: item.tracking ?? `PM-${item.label.toUpperCase()}-${42000 + stopIndex * 1111}`,
    instructions: item.instructions ?? INSTRUCTIONS_BY_STOP_TYPE[item.stopType] ?? "Complete delivery at stop.",
  };
};

const DeliveryHandScene = () => {
  const [visible, setVisible] = useState(devPreviewEnabled);
  const [items, setItems] = useState<DeliveryMailItem[]>(DEFAULT_DELIVERY_MAIL);
  const [regionName, setRegionName] = useState("Today's Deliveries");
  const [agentName, setAgentName] = useState("Delivery Agent 77");
  const [selectedId, setSelectedId] = useState<string | null>(
    DEFAULT_DELIVERY_MAIL[0]?.id ?? null,
  );
  const canvasHostRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<ReturnType<typeof createDeliveryItemsScene> | null>(null);

  useNuiEvent<OpenDeliveryHandPayload>("openDeliveryHand", (data) => {
    const nextItems = data.items?.length ? data.items : DEFAULT_DELIVERY_MAIL;
    if (data.items?.length) setItems(data.items);
    if (data.regionName) setRegionName(data.regionName);
    if (data.agentName) setAgentName(data.agentName);
    setSelectedId(nextItems[0]?.id ?? null);
    setVisible(true);
  });

  useNuiEvent("closeDeliveryHand", () => {
    setVisible(false);
    setSelectedId(null);
  });

  useEffect(() => {
    if (!visible || !canvasHostRef.current) return;

    sceneRef.current?.dispose();
    sceneRef.current = createDeliveryItemsScene(canvasHostRef.current, items, {
      initialSelectedId: selectedId,
      onSelect: setSelectedId,
    });

    return () => {
      sceneRef.current?.dispose();
      sceneRef.current = null;
    };
  }, [visible, items]);

  useEffect(() => {
    sceneRef.current?.setSelected(selectedId);
  }, [selectedId]);

  const selectedItem = useMemo(
    () => items.find((item) => item.id === selectedId) ?? items[0] ?? null,
    [items, selectedId],
  );

  const deliveryDetails = useMemo(
    () => getDeliveryDetails(selectedItem),
    [selectedItem],
  );

  const closeScene = () => {
    setVisible(false);
    setSelectedId(null);
    fetchNui("closeDeliveryHand").catch(() => undefined);
  };

  if (!visible) return null;

  return (
    <div className="delivery-hand-overlay">
      <div className="delivery-hand-shell">
        <header className="delivery-hand-header">
          <span className="delivery-hand-header-spacer" aria-hidden="true" />
          <h2 className="delivery-hand-title">{regionName}</h2>
          <div className="delivery-hand-header-right">
            <div className="delivery-hand-agent">
              <span className="delivery-hand-agent-avatar">
                <img src={avatarImg} alt="" />
              </span>
              <span className="delivery-hand-agent-name">{agentName}</span>
            </div>
            <button
              type="button"
              className="delivery-hand-gear"
              onClick={closeScene}
              aria-label="Close"
            >
              <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                <path d="M6 6l12 12M18 6L6 18" />
              </svg>
            </button>
          </div>
        </header>

        <div className="delivery-hand-body">
          <aside className="delivery-hand-sidebar">
            <div className="delivery-hand-list">
              {items.map((item) => {
                const itemShape = getDeliveryItemShape(item.stopType, item.noteType);
                return (
                <button
                  key={item.id}
                  type="button"
                  className={`delivery-hand-card${selectedId === item.id ? " is-selected" : ""}`}
                  onClick={() => setSelectedId(item.id)}
                >
                  <span className={`delivery-hand-note delivery-hand-note-badge ${item.noteType}`}>
                    {item.note}
                  </span>
                  <div className="delivery-hand-card-body">
                    <span className="delivery-hand-stop">{item.label}</span>
                    <img
                      src={getCardShapeImage(item)}
                      alt=""
                      className={`delivery-hand-card-icon${
                        itemShape === "box" ? " delivery-hand-card-icon--box" : ""
                      }`}
                      aria-hidden="true"
                    />
                    <div className="delivery-hand-card-content">
                      <p className="delivery-hand-address">{item.address}</p>
                      <p className="delivery-hand-type">
                        {STOP_TYPE_LABELS[item.stopType] ?? item.stopType}
                        {" · "}
                        {getItemShapeLabel(item)}
                      </p>
                    </div>
                  </div>
                </button>
                );
              })}
            </div>
          </aside>

          <section className="delivery-hand-panel">
            <div ref={canvasHostRef} className="delivery-hand-canvas" />

            <div className="delivery-hand-details">
              <span className="delivery-hand-details-kicker">Stop Details</span>
              <h3 className="delivery-hand-details-title">{deliveryDetails.adresse}</h3>

              <div className="delivery-hand-detail-row">
                <span className="delivery-hand-detail-label">Recipient:</span>
                <span className="delivery-hand-detail-value">{deliveryDetails.reciepent}</span>
              </div>
              <div className="delivery-hand-detail-row">
                <span className="delivery-hand-detail-label">Tracking:</span>
                <span className="delivery-hand-detail-value delivery-hand-detail-value--mono">
                  {deliveryDetails.tracking}
                </span>
              </div>
              <div className="delivery-hand-detail-row">
                <span className="delivery-hand-detail-label">Status</span>
                <span className="delivery-hand-status-pill">{deliveryDetails.status}</span>
              </div>
              <div className="delivery-hand-detail-row">
                <span className="delivery-hand-detail-label">Instructions:</span>
                <span className="delivery-hand-detail-value">{deliveryDetails.instructions}</span>
              </div>
              <div className="delivery-hand-detail-row">
                <span className="delivery-hand-detail-label">Proof of Delivery:</span>
                <span className="delivery-hand-proof-check" aria-hidden="true">
                  <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M4 12.5l5.2 5.2L20 6.5" />
                  </svg>
                </span>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
};

export default DeliveryHandScene;
