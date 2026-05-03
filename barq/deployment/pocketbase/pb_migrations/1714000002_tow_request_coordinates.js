/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const tow = app.findCollectionByNameOrId("tow_requests");
    const fields = [
      "pickup_lat",
      "pickup_lng",
      "destination_lat",
      "destination_lng",
      "driver_lat",
      "driver_lng",
    ];

    for (const name of fields) {
      try {
        const existing = tow.fields.getByName(name);
        if (!existing) {
          tow.fields.add(new NumberField({ name, onlyInt: false }));
        }
      } catch (_) {
        tow.fields.add(new NumberField({ name, onlyInt: false }));
      }
    }

    app.save(tow);
  },
  (app) => {
    const tow = app.findCollectionByNameOrId("tow_requests");
    for (const name of [
      "pickup_lat",
      "pickup_lng",
      "destination_lat",
      "destination_lng",
      "driver_lat",
      "driver_lng",
    ]) {
      try {
        tow.fields.removeByName(name);
      } catch (_) {}
    }
    app.save(tow);
  }
);
