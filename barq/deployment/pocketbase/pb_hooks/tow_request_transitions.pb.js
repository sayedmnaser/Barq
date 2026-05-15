/// <reference path="../pb_data/types.d.ts" />

const AUTO_COMPLETE_RADIUS_M = 150;
const TERMINAL = ["completed", "cancelled", "expired"];

const ALLOWED = {
  pending: ["assigned", "cancelled", "expired", "cancel_pending"],
  assigned: ["en_route", "cancelled", "cancel_pending"],
  en_route: ["completed", "cancelled", "cancel_pending"],
  cancel_pending: ["cancelled", "assigned", "en_route"],
};

function isSuperuser(e) {
  if (!e.auth) return false;
  try {
    return e.auth.collection().name === "_superusers";
  } catch (_) {
    return false;
  }
}

function haversineM(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const s1 = Math.sin(dLat / 2);
  const s2 = Math.sin(dLng / 2);
  const a =
    s1 * s1 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * s2 * s2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

onRecordUpdateRequest((e) => {
  if (isSuperuser(e)) {
    return e.next();
  }

  const old = e.record.original();
  const oldStatus = String(old.get("status") || "");
  const newStatus = String(e.record.get("status") || "");
  const authId = e.auth ? e.auth.id : "";
  const customerId = String(old.get("user") || "");
  const oldDriver = String(old.get("driver") || "");
  const newDriver = String(e.record.get("driver") || "");

  if (newStatus !== oldStatus) {
    if (TERMINAL.indexOf(oldStatus) !== -1) {
      throw new BadRequestError(
        "Cannot transition from terminal status: " + oldStatus
      );
    }
    const allowed = ALLOWED[oldStatus] || [];
    if (allowed.indexOf(newStatus) === -1) {
      throw new BadRequestError(
        "Illegal status transition: " + oldStatus + " -> " + newStatus
      );
    }

    if (newStatus === "assigned" && oldStatus === "pending") {
      if (newDriver !== authId || oldDriver !== "") {
        throw new BadRequestError("Invalid accept: driver field mismatch");
      }
    }

    if (newStatus === "en_route") {
      if (oldDriver !== authId) {
        throw new BadRequestError(
          "Only the assigned driver can start the trip"
        );
      }
    }

    if (newStatus === "completed") {
      if (oldDriver !== authId) {
        throw new BadRequestError(
          "Only the assigned driver can complete the trip"
        );
      }
      const dLat = num(e.record.get("driver_lat"));
      const dLng = num(e.record.get("driver_lng"));
      const destLat = num(e.record.get("destination_lat"));
      const destLng = num(e.record.get("destination_lng"));
      if (dLat === null || dLng === null || destLat === null || destLng === null) {
        throw new BadRequestError(
          "Completion requires driver and destination coordinates"
        );
      }
      if (haversineM(dLat, dLng, destLat, destLng) > AUTO_COMPLETE_RADIUS_M) {
        throw new BadRequestError("Driver not within completion radius");
      }
    }

    if (newStatus === "cancelled" || newStatus === "cancel_pending") {
      if (authId !== customerId && authId !== oldDriver) {
        throw new BadRequestError(
          "Only the customer or assigned driver can cancel"
        );
      }
    }

    if (newStatus === "expired") {
      if (authId !== customerId) {
        throw new BadRequestError(
          "Only the customer or cron can mark a request expired"
        );
      }
    }
  }

  if (newDriver !== oldDriver) {
    const isPendingAccept =
      oldStatus === "pending" && newStatus === "assigned" && newDriver === authId;
    if (!isPendingAccept) {
      throw new BadRequestError(
        "driver field can only change during a pending -> assigned accept"
      );
    }
  }

  e.next();
}, "tow_requests");
