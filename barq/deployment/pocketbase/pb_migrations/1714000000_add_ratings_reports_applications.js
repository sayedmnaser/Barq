/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    // ---------- ratings ----------
    const ratings = new Collection({
      type: "base",
      name: "ratings",
      listRule: '@request.auth.id != "" && (user = @request.auth.id || driver = @request.auth.id)',
      viewRule: '@request.auth.id != "" && (user = @request.auth.id || driver = @request.auth.id)',
      createRule: '@request.auth.id != "" && user = @request.auth.id',
      updateRule: null,
      deleteRule: null,
      fields: [
        { name: "user", type: "relation", required: true, collectionId: app.findCollectionByNameOrId("users").id, maxSelect: 1, cascadeDelete: false },
        { name: "driver", type: "relation", required: true, collectionId: app.findCollectionByNameOrId("users").id, maxSelect: 1, cascadeDelete: false },
        { name: "tow_request", type: "relation", required: true, collectionId: app.findCollectionByNameOrId("tow_requests").id, maxSelect: 1, cascadeDelete: true },
        { name: "stars", type: "number", required: true, min: 1, max: 5, onlyInt: true },
        { name: "comment", type: "text", max: 1000 },
        { name: "created", type: "autodate", onCreate: true },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_rating_per_request ON ratings (tow_request)",
        "CREATE INDEX idx_rating_driver ON ratings (driver)",
      ],
    });
    app.save(ratings);

    // ---------- driver_reports ----------
    const reports = new Collection({
      type: "base",
      name: "driver_reports",
      listRule: '@request.auth.id != "" && reporter = @request.auth.id',
      viewRule: '@request.auth.id != "" && reporter = @request.auth.id',
      createRule: '@request.auth.id != "" && reporter = @request.auth.id',
      updateRule: null,
      deleteRule: null,
      fields: [
        { name: "reporter", type: "relation", required: true, collectionId: app.findCollectionByNameOrId("users").id, maxSelect: 1 },
        { name: "driver", type: "relation", required: true, collectionId: app.findCollectionByNameOrId("users").id, maxSelect: 1 },
        { name: "tow_request", type: "relation", required: false, collectionId: app.findCollectionByNameOrId("tow_requests").id, maxSelect: 1 },
        { name: "category", type: "select", required: true, maxSelect: 1, values: ["rude", "unsafe", "no_show", "damage", "fraud", "other"] },
        { name: "description", type: "text", required: true, max: 2000 },
        { name: "photos", type: "file", maxSelect: 5, maxSize: 10485760, mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
        { name: "ai_verdict", type: "text", max: 4000 },
        { name: "ai_action", type: "select", maxSelect: 1, values: ["dismiss", "warn", "suspend", "escalate"] },
        { name: "ai_confidence", type: "number", min: 0, max: 1 },
        { name: "status", type: "select", required: true, maxSelect: 1, values: ["pending_review", "ai_reviewed", "admin_actioned", "closed"] },
        { name: "created", type: "autodate", onCreate: true },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: [
        "CREATE INDEX idx_report_driver ON driver_reports (driver)",
        "CREATE INDEX idx_report_status ON driver_reports (status)",
      ],
    });
    app.save(reports);

    // ---------- driver_applications ----------
    const apps = new Collection({
      type: "base",
      name: "driver_applications",
      listRule: '@request.auth.id != "" && user = @request.auth.id',
      viewRule: '@request.auth.id != "" && user = @request.auth.id',
      createRule: '@request.auth.id != "" && user = @request.auth.id',
      updateRule: '@request.auth.id != "" && user = @request.auth.id && status = "submitted"',
      deleteRule: null,
      fields: [
        { name: "user", type: "relation", required: true, collectionId: app.findCollectionByNameOrId("users").id, maxSelect: 1, cascadeDelete: true },
        { name: "full_name", type: "text", required: true, max: 200 },
        { name: "plate_number", type: "text", required: true, max: 32 },
        { name: "license_front", type: "file", required: true, maxSelect: 1, maxSize: 10485760, mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
        { name: "license_back", type: "file", required: true, maxSelect: 1, maxSize: 10485760, mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
        { name: "national_id", type: "file", required: true, maxSelect: 1, maxSize: 10485760, mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
        { name: "car_photo", type: "file", required: true, maxSelect: 1, maxSize: 10485760, mimeTypes: ["image/jpeg", "image/png", "image/webp"] },
        { name: "ai_verdict", type: "text", max: 4000 },
        { name: "ai_decision", type: "select", maxSelect: 1, values: ["approved", "rejected", "needs_review"] },
        { name: "ai_confidence", type: "number", min: 0, max: 1 },
        { name: "status", type: "select", required: true, maxSelect: 1, values: ["submitted", "ai_reviewed", "approved", "rejected"] },
        { name: "created", type: "autodate", onCreate: true },
        { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_app_user ON driver_applications (user)",
        "CREATE INDEX idx_app_status ON driver_applications (status)",
      ],
    });
    app.save(apps);

    // ---------- tow_requests: add photo + rated fields ----------
    const tow = app.findCollectionByNameOrId("tow_requests");
    tow.fields.add(new FileField({
      name: "pickup_photo",
      maxSelect: 1,
      maxSize: 10485760,
      mimeTypes: ["image/jpeg", "image/png", "image/webp"],
    }));
    tow.fields.add(new FileField({
      name: "dropoff_photo",
      maxSelect: 1,
      maxSize: 10485760,
      mimeTypes: ["image/jpeg", "image/png", "image/webp"],
    }));
    tow.fields.add(new FileField({
      name: "damage_photos",
      maxSelect: 5,
      maxSize: 10485760,
      mimeTypes: ["image/jpeg", "image/png", "image/webp"],
    }));
    tow.fields.add(new BoolField({ name: "rated" }));
    app.save(tow);

    // ---------- users: suspension + application_status ----------
    const users = app.findCollectionByNameOrId("users");
    users.fields.add(new BoolField({ name: "is_suspended" }));
    users.fields.add(new TextField({ name: "suspension_reason", max: 500 }));
    users.fields.add(new SelectField({
      name: "application_status",
      maxSelect: 1,
      values: ["none", "pending", "approved", "rejected"],
    }));
    app.save(users);
  },
  (app) => {
    // ---------- down ----------
    for (const name of ["ratings", "driver_reports", "driver_applications"]) {
      try {
        const col = app.findCollectionByNameOrId(name);
        app.delete(col);
      } catch (_) {}
    }

    try {
      const tow = app.findCollectionByNameOrId("tow_requests");
      for (const f of ["pickup_photo", "dropoff_photo", "damage_photos", "rated"]) {
        const field = tow.fields.getByName(f);
        if (field) tow.fields.removeByName(f);
      }
      app.save(tow);
    } catch (_) {}

    try {
      const users = app.findCollectionByNameOrId("users");
      for (const f of ["is_suspended", "suspension_reason", "application_status"]) {
        const field = users.fields.getByName(f);
        if (field) users.fields.removeByName(f);
      }
      app.save(users);
    } catch (_) {}
  }
);
