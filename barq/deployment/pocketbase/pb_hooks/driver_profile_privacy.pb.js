/// <reference path="../pb_data/types.d.ts" />

const SENSITIVE = ["driver_phone", "license_plate"];

function isSuperuser(e) {
  if (!e.auth) return false;
  try {
    return e.auth.collection().name === "_superusers";
  } catch (_) {
    return false;
  }
}

function stripIfNotOwner(record, authId) {
  if (!record) return;
  const ownerId = String(record.get("user") || "");
  if (ownerId === authId) return;
  for (const f of SENSITIVE) {
    record.set(f, "");
  }
}

onRecordsListRequest((e) => {
  if (isSuperuser(e)) return e.next();
  const authId = e.auth ? e.auth.id : "";
  const items = (e.result && e.result.items) || [];
  for (const r of items) {
    stripIfNotOwner(r, authId);
  }
  e.next();
}, "driver_profiles");

onRecordViewRequest((e) => {
  if (isSuperuser(e)) return e.next();
  const authId = e.auth ? e.auth.id : "";
  stripIfNotOwner(e.record, authId);
  e.next();
}, "driver_profiles");
