import { useEffect, useMemo, useRef, useState } from "react";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";
import {
  computeInitialMapView,
  computeRouteViewport,
  formatDistance,
  gameToFullMapPercent,
  type GameCoord,
} from "../utils/gtaMap";
import { getNuiAssetUrl } from "../utils/misc";
import "./RouteMinigame.css";

interface RouteStop {
  id: number;
  x: number;
  y: number;
  z?: number;
  label: string;
  urgent?: boolean;
}

interface RouteMinigamePayload {
  depot: GameCoord & { label: string };
  stops: RouteStop[];
  urgentLabels?: string;
  regionName?: string;
  mapUrl?: string;
  mapUrlFallback?: string;
  playerDistance?: number;
  optimalDistance?: number;
}

const STOP_COLORS = ["#8bff73", "#72e05a", "#5cc743", "#4ab832", "#3aa028"];
const DEFAULT_MAP_URL = getNuiAssetUrl("web/dist/gta-map-dark.jpg");
const FALLBACK_MAP_URL = getNuiAssetUrl("web/dist/gta-map-dark.png");
const ZOOM_STEP = 1.18;
const MIN_ZOOM_LEVEL = 0.35;
const MAX_MAP_SCALE = 96;
const DRAG_CLICK_THRESHOLD = 4;
const ROUTE_SUCCESS_CLOSE_DELAY_MS = 3000;

type RouteFeedbackType = "success" | "error" | null;

interface DragState {
  active: boolean;
  moved: boolean;
  startX: number;
  startY: number;
  panX: number;
  panY: number;
}

const RouteMinigame = () => {
  const [visible, setVisible] = useState(false);
  const [depot, setDepot] = useState<(GameCoord & { label: string }) | null>(null);
  const [stops, setStops] = useState<RouteStop[]>([]);
  const [urgentLabels, setUrgentLabels] = useState("");
  const [regionName, setRegionName] = useState("Route Area");
  const [mapUrl, setMapUrl] = useState(DEFAULT_MAP_URL);
  const [mapUrlFallback, setMapUrlFallback] = useState(FALLBACK_MAP_URL);
  const [selectedOrder, setSelectedOrder] = useState<number[]>([]);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [feedbackType, setFeedbackType] = useState<RouteFeedbackType>(null);
  const [routeConfirmed, setRouteConfirmed] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [zoomLevel, setZoomLevel] = useState(1);
  const [isDragging, setIsDragging] = useState(false);
  const viewportRef = useRef<HTMLDivElement>(null);
  const dragRef = useRef<DragState>({
    active: false,
    moved: false,
    startX: 0,
    startY: 0,
    panX: 0,
    panY: 0,
  });
  const panRef = useRef(pan);
  const zoomLevelRef = useRef(zoomLevel);
  const closeTimerRef = useRef<number | null>(null);

  const clearCloseTimer = () => {
    if (closeTimerRef.current !== null) {
      window.clearTimeout(closeTimerRef.current);
      closeTimerRef.current = null;
    }
  };

  const resetFeedback = () => {
    setFeedback(null);
    setFeedbackType(null);
  };

  useEffect(() => {
    panRef.current = pan;
  }, [pan]);

  useEffect(() => {
    zoomLevelRef.current = zoomLevel;
  }, [zoomLevel]);

  useEffect(() => {
    return () => clearCloseTimer();
  }, []);

  useNuiEvent<RouteMinigamePayload>("openRouteMinigame", (data) => {
    clearCloseTimer();
    setDepot(data.depot);
    setStops(data.stops);
    setUrgentLabels(data.urgentLabels || "");
    setRegionName(data.regionName || "Route Area");
    setMapUrl(data.mapUrl || DEFAULT_MAP_URL);
    setMapUrlFallback(data.mapUrlFallback || FALLBACK_MAP_URL);
    setSelectedOrder([]);
    resetFeedback();
    setRouteConfirmed(false);
    setPan({ x: 0, y: 0 });
    setZoomLevel(1);
    setIsDragging(false);
    setVisible(true);
  });

  useNuiEvent("closeRouteMinigame", () => {
    clearCloseTimer();
    setVisible(false);
    setSelectedOrder([]);
    resetFeedback();
    setUrgentLabels("");
    setRouteConfirmed(false);
    setSubmitting(false);
    setPan({ x: 0, y: 0 });
    setZoomLevel(1);
    setIsDragging(false);
  });

  const viewport = useMemo(() => {
    if (!depot) return null;
    return computeRouteViewport([depot, ...stops]);
  }, [depot, stops]);

  const mapView = useMemo(
    () => (viewport ? computeInitialMapView(viewport) : null),
    [viewport],
  );

  const zoomLimits = useMemo(() => {
    if (!mapView) {
      return { min: MIN_ZOOM_LEVEL, max: 32 };
    }

    // Wide routes start zoomed out — allow much more user zoom-in before hitting the cap.
    const max = Math.max(16, Math.min(64, MAX_MAP_SCALE / mapView.zoom));
    return { min: MIN_ZOOM_LEVEL, max };
  }, [mapView]);

  const mapScale = mapView ? mapView.zoom * zoomLevel : 1;

  const resetMapView = () => {
    if (!mapView || !viewportRef.current) return;
    const size = Math.min(viewportRef.current.clientWidth, viewportRef.current.clientHeight);
    const fitScale = mapView.zoom;
    setZoomLevel(1);
    setPan({
      x: ((50 - mapView.originX) / 100) * size * fitScale,
      y: ((50 - mapView.originY) / 100) * size * fitScale,
    });
  };

  useEffect(() => {
    if (!visible || !mapView) return;
    const frame = requestAnimationFrame(resetMapView);
    return () => cancelAnimationFrame(frame);
  }, [visible, mapView, depot, stops]);

  const depotPoint = useMemo(() => (depot ? gameToFullMapPercent(depot) : null), [depot]);

  const stopPoints = useMemo(
    () => stops.map((stop) => ({ stop, point: gameToFullMapPercent(stop) })),
    [stops],
  );

  const urgentStopIds = useMemo(
    () => new Set(stops.filter((stop) => stop.urgent).map((stop) => stop.id)),
    [stops],
  );

  const isUrgentOrderValid = (order: number[]) => {
    if (urgentStopIds.size === 0) return true;

    let maxUrgentPos = 0;
    let minRegularPos = order.length + 1;

    order.forEach((stopId, index) => {
      const pos = index + 1;
      if (urgentStopIds.has(stopId)) {
        maxUrgentPos = Math.max(maxUrgentPos, pos);
      } else if (pos < minRegularPos) {
        minRegularPos = pos;
      }
    });

    return maxUrgentPos < minRegularPos;
  };

  const routeSegments = useMemo(() => {
    if (!depotPoint) return [];

    const segments: Array<{ x1: number; y1: number; x2: number; y2: number }> = [];
    let from = depotPoint;

    for (const stopId of selectedOrder) {
      const target = stopPoints.find((entry) => entry.stop.id === stopId);
      if (!target) continue;
      segments.push({
        x1: from.left,
        y1: from.top,
        x2: target.point.left,
        y2: target.point.top,
      });
      from = target.point;
    }

    if (selectedOrder.length === stops.length) {
      segments.push({
        x1: from.left,
        y1: from.top,
        x2: depotPoint.left,
        y2: depotPoint.top,
      });
    }

    return segments;
  }, [depotPoint, selectedOrder, stopPoints, stops.length]);

  const handleStopClick = (stopId: number) => {
    if (dragRef.current.moved || routeConfirmed) return;
    if (selectedOrder.includes(stopId)) return;
    setSelectedOrder((prev) => [...prev, stopId]);
    resetFeedback();
  };

  const endDrag = () => {
    if (!dragRef.current.active) return;
    dragRef.current.active = false;
    setIsDragging(false);
  };

  const updateDragPan = (clientX: number, clientY: number) => {
    if (!dragRef.current.active) return;

    const deltaX = clientX - dragRef.current.startX;
    const deltaY = clientY - dragRef.current.startY;

    if (!dragRef.current.moved && Math.hypot(deltaX, deltaY) > DRAG_CLICK_THRESHOLD) {
      dragRef.current.moved = true;
    }

    setPan({
      x: dragRef.current.panX + deltaX,
      y: dragRef.current.panY + deltaY,
    });
  };

  useEffect(() => {
    if (!isDragging) return;

    const onPointerMove = (event: PointerEvent) => updateDragPan(event.clientX, event.clientY);
    const onMouseMove = (event: MouseEvent) => updateDragPan(event.clientX, event.clientY);

    window.addEventListener("pointermove", onPointerMove);
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("pointerup", endDrag);
    window.addEventListener("pointercancel", endDrag);
    window.addEventListener("mouseup", endDrag);

    return () => {
      window.removeEventListener("pointermove", onPointerMove);
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("pointerup", endDrag);
      window.removeEventListener("pointercancel", endDrag);
      window.removeEventListener("mouseup", endDrag);
    };
  }, [isDragging]);

  const handleUndo = () => {
    if (routeConfirmed) return;
    setSelectedOrder((prev) => prev.slice(0, -1));
    resetFeedback();
  };

  const handleReset = () => {
    if (routeConfirmed) return;
    setSelectedOrder([]);
    resetFeedback();
  };

  const scheduleRouteClose = () => {
    clearCloseTimer();
    closeTimerRef.current = window.setTimeout(async () => {
      try {
        await fetchNui("closeRouteMinigame", {}, {});
      } catch (error) {
        console.error(error);
        setVisible(false);
      }
    }, ROUTE_SUCCESS_CLOSE_DELAY_MS);
  };

  const handleSubmit = async () => {
    if (selectedOrder.length !== stops.length || submitting || routeConfirmed) return;

    if (!isUrgentOrderValid(selectedOrder)) {
      setFeedbackType("error");
      setFeedback(
        urgentLabels
          ? `Deliver URGENT mail first! Stops ${urgentLabels} must come before regular stops.`
          : "Deliver URGENT mail first! Urgent stops must come before regular stops.",
      );
      return;
    }

    setSubmitting(true);
    resetFeedback();

    try {
      const result = await fetchNui<{
        success: boolean;
        playerDistance?: number;
        optimalDistance?: number;
        message?: string;
      }>(
        "submitRouteOrder",
        { order: selectedOrder },
        { success: false, message: "Route validation failed." },
      );

      if (result.success) {
        const playerText = result.playerDistance ? formatDistance(result.playerDistance) : "—";
        setFeedbackType("success");
        setFeedback(
          result.message || `Perfect route! URGENT mail first. Total distance: ${playerText}.`,
        );
        setRouteConfirmed(true);
        scheduleRouteClose();
        return;
      }

      setFeedbackType("error");
      setFeedback(result.message || "Route validation failed. Try again.");
    } catch (error) {
      console.error(error);
      setFeedbackType("error");
      setFeedback("Could not validate your route. Try again.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleMapError = () => {
    if (mapUrl !== mapUrlFallback) {
      setMapUrl(mapUrlFallback);
    }
  };

  const clampZoomLevel = (value: number) => Math.min(zoomLimits.max, Math.max(zoomLimits.min, value));

  const applyZoomAtPoint = (nextZoomLevel: number, anchorX: number, anchorY: number) => {
    const currentZoom = zoomLevelRef.current;
    const currentPan = panRef.current;
    const clamped = clampZoomLevel(nextZoomLevel);
    if (clamped === currentZoom) return;

    const ratio = clamped / currentZoom;
    setPan({
      x: anchorX - (anchorX - currentPan.x) * ratio,
      y: anchorY - (anchorY - currentPan.y) * ratio,
    });
    setZoomLevel(clamped);
  };

  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport || !visible) return;

    const onWheel = (event: WheelEvent) => {
      event.preventDefault();
      event.stopPropagation();

      const rect = viewport.getBoundingClientRect();
      const factor = event.deltaY < 0 ? ZOOM_STEP : 1 / ZOOM_STEP;
      const anchorX = event.clientX - rect.left - rect.width / 2;
      const anchorY = event.clientY - rect.top - rect.height / 2;
      applyZoomAtPoint(zoomLevelRef.current * factor, anchorX, anchorY);
    };

    viewport.addEventListener("wheel", onWheel, { passive: false });
    return () => viewport.removeEventListener("wheel", onWheel);
  }, [visible, zoomLimits.max, zoomLimits.min]);

  const handleZoomButton = (direction: "in" | "out" | "reset") => {
    if (direction === "reset") {
      resetMapView();
      return;
    }

    const factor = direction === "in" ? ZOOM_STEP : 1 / ZOOM_STEP;
    applyZoomAtPoint(zoomLevelRef.current * factor, 0, 0);
  };

  const startDrag = (clientX: number, clientY: number) => {
    const currentPan = panRef.current;
    dragRef.current = {
      active: true,
      moved: false,
      startX: clientX,
      startY: clientY,
      panX: currentPan.x,
      panY: currentPan.y,
    };
    setIsDragging(true);
  };

  const handleViewportPointerDown = (event: React.PointerEvent<HTMLDivElement>) => {
    if (event.button !== 0) return;
    event.preventDefault();
    startDrag(event.clientX, event.clientY);
  };

  const handleViewportMouseDown = (event: React.MouseEvent<HTMLDivElement>) => {
    if (event.button !== 0) return;
    event.preventDefault();
    startDrag(event.clientX, event.clientY);
  };

  if (!visible || !depot || !depotPoint || !viewport || !mapView) return null;

  const routeReady = selectedOrder.length === stops.length;

  return (
    <div className="route-minigame">
      <div className="route-minigame__panel">
        <div className="route-minigame__header">
          <div>
            <h2>Plan Your Mail Route</h2>
            <p>
              {regionName} — deliver{" "}
              <span className="route-minigame__urgent-text">URGENT</span> mail first
              {urgentLabels ? ` (stops ${urgentLabels})` : ""}, then find the shortest route.
            </p>
          </div>
          <div className="route-minigame__progress">
            {selectedOrder.length}/{stops.length} stops selected
          </div>
        </div>

        <div className="route-minigame__body">
          <div className="route-minigame__map-wrap">
            <div
              ref={viewportRef}
              className={`route-minigame__map-viewport ${isDragging ? "route-minigame__map-viewport--dragging" : ""}`}
              onPointerDown={handleViewportPointerDown}
              onMouseDown={handleViewportMouseDown}
            >
              <div className="route-minigame__zoom-controls" onPointerDown={(event) => event.stopPropagation()}>
                <button type="button" className="route-minigame__zoom-btn" onClick={() => handleZoomButton("in")} aria-label="Zoom in">
                  +
                </button>
                <button type="button" className="route-minigame__zoom-btn" onClick={() => handleZoomButton("out")} aria-label="Zoom out">
                  −
                </button>
                <button type="button" className="route-minigame__zoom-btn route-minigame__zoom-btn--reset" onClick={() => handleZoomButton("reset")} aria-label="Reset map view">
                  ⟲
                </button>
              </div>

              <div
                className="route-minigame__map-layer"
                style={{
                  width: `calc(min(100cqw, 100cqh) * ${mapScale})`,
                  transform: `translate(calc(-50% + ${pan.x}px), calc(-50% + ${pan.y}px))`,
                }}
              >
                <img
                  className="route-minigame__map-image"
                  src={mapUrl}
                  alt="GTA route map"
                  draggable={false}
                  onError={handleMapError}
                />

                <svg className="route-minigame__lines" viewBox="0 0 100 100" preserveAspectRatio="none">
                  {routeSegments.map((segment, index) => (
                    <line
                      key={`segment-${index}`}
                      x1={segment.x1}
                      y1={segment.y1}
                      x2={segment.x2}
                      y2={segment.y2}
                      className={
                        index === routeSegments.length - 1 && routeReady
                          ? "route-minigame__line route-minigame__line--return"
                          : "route-minigame__line"
                      }
                    />
                  ))}
                </svg>

                <button
                  type="button"
                  className="route-minigame__marker route-minigame__marker--depot"
                  style={{ left: `${depotPoint.left}%`, top: `${depotPoint.top}%` }}
                  title={depot.label}
                  onClick={() => {}}
                  aria-label="Depot"
                >
                  <span className="route-minigame__marker-box route-minigame__marker-box--depot">
                    <span className="route-minigame__marker-label">DEPOT</span>
                  </span>
                </button>

                {stopPoints.map(({ stop, point }, index) => {
                  const orderIndex = selectedOrder.indexOf(stop.id);
                  const isSelected = orderIndex >= 0;

                  return (
                    <button
                      key={stop.id}
                      type="button"
                      className={`route-minigame__marker route-minigame__marker--stop ${stop.urgent ? "route-minigame__marker--urgent" : ""} ${isSelected ? "route-minigame__marker--selected" : ""}`}
                      style={{
                        left: `${point.left}%`,
                        top: `${point.top}%`,
                        ["--marker-color" as string]: stop.urgent ? "#ff6b6b" : STOP_COLORS[index % STOP_COLORS.length],
                      }}
                      onClick={() => handleStopClick(stop.id)}
                      title={
                        stop.urgent
                          ? `URGENT Stop ${stop.label}${isSelected ? ` — #${orderIndex + 1}` : ""}`
                          : isSelected
                            ? `Stop ${stop.label} — #${orderIndex + 1}`
                            : `Stop ${stop.label}`
                      }
                      aria-label={stop.urgent ? `Urgent stop ${stop.label}` : `Stop ${stop.label}`}
                    >
                      <span className="route-minigame__marker-box">
                        <span className="route-minigame__marker-label">{stop.label}</span>
                        {stop.urgent && <span className="route-minigame__marker-urgent">!</span>}
                        {isSelected && (
                          <span className="route-minigame__marker-order">{orderIndex + 1}</span>
                        )}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          <div className="route-minigame__sidebar">
            <div className="route-minigame__sidebar-scroll">
              {feedback && (
                <div
                  className={`route-minigame__feedback ${
                    feedbackType === "success"
                      ? "route-minigame__feedback--success"
                      : "route-minigame__feedback--error"
                  }`}
                >
                  {feedback}
                </div>
              )}

              <div className="route-minigame__sequence route-minigame__card">
                <h3 className="route-minigame__card-title">Your Route</h3>
                {selectedOrder.length === 0 ? (
                  <p className="route-minigame__sequence-empty">
                    Click stops in visit order. Red stops are URGENT — deliver those before regular mail, then keep the route short.
                  </p>
                ) : (
                  <ol className="route-minigame__sequence-list">
                    <li className="route-minigame__sequence-item route-minigame__sequence-item--depot">
                      <span className="route-minigame__sequence-chip route-minigame__sequence-chip--depot">DEPOT</span>
                      <span>Start</span>
                    </li>
                    {selectedOrder.map((stopId) => {
                      const stop = stops.find((entry) => entry.id === stopId);
                      const orderIndex = selectedOrder.indexOf(stopId);
                      return (
                        <li
                          key={stopId}
                          className={`route-minigame__sequence-item ${stop?.urgent ? "route-minigame__sequence-item--urgent" : ""}`}
                        >
                          <span className={`route-minigame__sequence-chip ${stop?.urgent ? "route-minigame__sequence-chip--urgent" : ""}`}>
                            {stop?.label ?? stopId}
                          </span>
                          <span>
                            {stop?.urgent ? "URGENT " : ""}Stop {stop?.label ?? stopId}
                          </span>
                          <span className="route-minigame__sequence-rank">#{orderIndex + 1}</span>
                        </li>
                      );
                    })}
                    {routeReady && (
                      <li className="route-minigame__sequence-item route-minigame__sequence-item--return">
                        <span className="route-minigame__sequence-chip route-minigame__sequence-chip--depot">DEPOT</span>
                        <span className="route-minigame__sequence-return">Return to Depot</span>
                      </li>
                    )}
                  </ol>
                )}
              </div>
            </div>

            <div className="route-minigame__sidebar-footer">
              <div className="route-minigame__actions">
              <button
                type="button"
                className="route-minigame__button route-minigame__button--ghost"
                onClick={handleUndo}
                disabled={selectedOrder.length === 0 || routeConfirmed}
              >
                Undo
              </button>
              <button
                type="button"
                className="route-minigame__button route-minigame__button--ghost"
                onClick={handleReset}
                disabled={selectedOrder.length === 0 || routeConfirmed}
              >
                Reset
              </button>
              <button
                type="button"
                className="route-minigame__button route-minigame__button--primary"
                onClick={handleSubmit}
                disabled={!routeReady || submitting || routeConfirmed}
              >
                {routeConfirmed ? "Route Confirmed" : submitting ? "Checking..." : "Confirm Route"}
              </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default RouteMinigame;
