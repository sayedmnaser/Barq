/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const profiles = app.findCollectionByNameOrId("driver_profiles");
    profiles.listRule =
      '@request.auth.id != "" && (user = @request.auth.id || is_available = true)';
    profiles.viewRule =
      '@request.auth.id != "" && (user = @request.auth.id || is_available = true)';
    app.save(profiles);
  },
  (app) => {
    const profiles = app.findCollectionByNameOrId("driver_profiles");
    profiles.listRule = "@request.auth.id = user";
    profiles.viewRule = "@request.auth.id = user";
    app.save(profiles);
  }
);
