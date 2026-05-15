/// <reference path="../pb_data/types.d.ts" />

function isSuperuser(e) {
  if (!e.auth) return false;
  try {
    return e.auth.collection().name === "_superusers";
  } catch (_) {
    return false;
  }
}

function declinedContains(record, userId) {
  if (!record || !userId) return false;
  const list = record.get("declined_by");
  if (!list) return false;
  if (Array.isArray(list)) {
    return list.indexOf(userId) !== -1;
  }
  if (typeof list === "string") {
    return list === userId;
  }
  return false;
}

function isDriverViewer(e) {
  if (!e.auth) return false;
  try {
    if (e.auth.collection().name === "_superusers") return false;
  } catch (_) {}
  const flag = e.auth.get("Driver");
  return flag === true || flag === "true";
}

onRecordsListRequest((e) => {
  if (isSuperuser(e)) return e.next();
  if (!e.auth || !isDriverViewer(e)) return e.next();
  const authId = e.auth.id;
  const items = (e.result && e.result.items) || [];
  const filtered = items.filter((r) => {
    if (!r) return false;
    if (r.get("user") === authId) return true;
    if (r.get("driver") === authId) return true;
    return !declinedContains(r, authId);
  });
  if (filtered.length !== items.length) {
    e.result.items = filtered;
    if (typeof e.result.totalItems === "number") {
      e.result.totalItems -= items.length - filtered.length;
    }
  }
  e.next();
}, "tow_requests");

onRecordViewRequest((e) => {
  if (isSuperuser(e)) return e.next();
  if (!e.auth || !isDriverViewer(e)) return e.next();
  const authId = e.auth.id;
  const r = e.record;
  if (r && r.get("user") !== authId && r.get("driver") !== authId &&
      declinedContains(r, authId)) {
    throw new ForbiddenError("This request was previously declined.");
  }
  e.next();
}, "tow_requests");

onRecordUpdateRequest((e) => {
  if (isSuperuser(e)) return e.next();
  if (!e.auth || !isDriverViewer(e)) return e.next();
  const authId = e.auth.id;
  const old = e.record.original();
  if (
    old.get("user") !== authId &&
    old.get("driver") !== authId &&
    declinedContains(old, authId)
  ) {
    const newDeclined = e.record.get("declined_by");
    const onlyTouchingDeclined =
      Array.isArray(newDeclined) && newDeclined.indexOf(authId) !== -1;
    if (!onlyTouchingDeclined) {
      throw new ForbiddenError(
        "Driver previously declined this request and cannot modify it."
      );
    }
  }
  e.next();
}, "tow_requests");
