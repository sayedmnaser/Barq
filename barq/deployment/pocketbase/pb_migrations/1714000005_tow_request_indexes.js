/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");
    c.indexes = [
      "CREATE INDEX `idx_tow_status_created` ON `tow_requests` (`status`, `created`)",
      "CREATE INDEX `idx_tow_driver` ON `tow_requests` (`driver`)",
      "CREATE INDEX `idx_tow_user` ON `tow_requests` (`user`)",
    ];
    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");
    c.indexes = [];
    app.save(c);
  }
);
