// Calibrated for the standard 8192x8192 GTA V atlas (gta-v-map-leaflet / Flamm64).
const LEAFLET_SCALE_X = 0.02072;
const LEAFLET_OFFSET_X = 117.3;
const LEAFLET_SCALE_Y = -0.0205;
const LEAFLET_OFFSET_Y = 172.8;
const MAP_CRS_SIZE = 256;

export interface GameCoord {
  x: number;
  y: number;
  z?: number;
}

export interface MapPoint {
  left: number;
  top: number;
}

export interface MapViewport {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
}

export interface MapViewState {
  zoom: number;
  originX: number;
  originY: number;
}

export function gameToCrs(x: number, y: number): { x: number; y: number } {
  return {
    x: LEAFLET_SCALE_X * x + LEAFLET_OFFSET_X,
    y: LEAFLET_SCALE_Y * y + LEAFLET_OFFSET_Y,
  };
}

/** Position on the full 8192 atlas image (0-100%). */
export function gameToFullMapPercent(coords: GameCoord): MapPoint {
  const crs = gameToCrs(coords.x, coords.y);
  return {
    left: (crs.x / MAP_CRS_SIZE) * 100,
    top: (crs.y / MAP_CRS_SIZE) * 100,
  };
}

export function computeRouteViewport(
  points: GameCoord[],
  options?: { paddingRatio?: number; minClusterSpan?: number },
): MapViewport {
  const paddingRatio = options?.paddingRatio ?? 0.38;
  const minClusterSpan = options?.minClusterSpan ?? 900;

  const xs = points.map((point) => point.x);
  const ys = points.map((point) => point.y);

  let minX = Math.min(...xs);
  let maxX = Math.max(...xs);
  let minY = Math.min(...ys);
  let maxY = Math.max(...ys);

  let spanX = maxX - minX;
  let spanY = maxY - minY;

  if (spanX < 400) {
    const centerX = (minX + maxX) / 2;
    minX = centerX - minClusterSpan / 2;
    maxX = centerX + minClusterSpan / 2;
    spanX = minClusterSpan;
  }

  if (spanY < 400) {
    const centerY = (minY + maxY) / 2;
    minY = centerY - minClusterSpan / 2;
    maxY = centerY + minClusterSpan / 2;
    spanY = minClusterSpan;
  }

  const padX = spanX * paddingRatio;
  const padY = spanY * paddingRatio;

  return {
    minX: minX - padX,
    maxX: maxX + padX,
    minY: minY - padY,
    maxY: maxY + padY,
  };
}

/** Uniform zoom so the route area fits without stretching the square atlas. */
export function computeInitialMapView(
  viewport: MapViewport,
  padding = 1.32,
): MapViewState {
  const topLeft = gameToFullMapPercent({ x: viewport.minX, y: viewport.maxY });
  const bottomRight = gameToFullMapPercent({ x: viewport.maxX, y: viewport.minY });

  const regionWidth = Math.max(bottomRight.left - topLeft.left, 0.75);
  const regionHeight = Math.max(bottomRight.top - topLeft.top, 0.75);
  const originX = (topLeft.left + bottomRight.left) / 2;
  const originY = (topLeft.top + bottomRight.top) / 2;

  const zoomX = 100 / (regionWidth * padding);
  const zoomY = 100 / (regionHeight * padding);
  const zoom = Math.min(zoomX, zoomY);

  return { zoom, originX, originY };
}

export function formatDistance(meters: number): string {
  if (meters >= 1000) {
    return `${(meters / 1000).toFixed(2)} km`;
  }
  return `${Math.round(meters)} m`;
}
