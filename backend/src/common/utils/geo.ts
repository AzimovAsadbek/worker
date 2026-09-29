const EARTH_RADIUS_M = 6_371_008.8;
const toRad = (d: number) => (d * Math.PI) / 180;

/** Great-circle distance in meters (haversine). */
export function distanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a)));
}

export type GeofenceVerdict = 'INSIDE' | 'UNCERTAIN' | 'OUTSIDE';

/**
 * INSIDE    — the reported point is within the radius.
 * UNCERTAIN — point outside the radius but within the GPS accuracy circle (could be inside).
 * OUTSIDE   — even the most favourable point of the accuracy circle is outside the radius.
 */
export function geofenceVerdict(distance: number, radius: number, accuracy: number | null | undefined): GeofenceVerdict {
  if (distance <= radius) return 'INSIDE';
  const acc = Math.max(0, Math.min(accuracy ?? 0, 500)); // accuracy claims beyond 500 m give no benefit
  return distance - acc <= radius ? 'UNCERTAIN' : 'OUTSIDE';
}
