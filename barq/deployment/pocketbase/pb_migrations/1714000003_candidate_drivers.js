/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const tow = app.findCollectionByNameOrId("tow_requests");
    const users = app.findCollectionByNameOrId("_pb_users_auth_");

    try {
      const existing = tow.fields.getByName("candidate_drivers");
      if (existing) {
        return;
      }
    } catch (_) {}

    tow.fields.add(
      new RelationField({
        name: "candidate_drivers",
        collectionId: users.id,
        maxSelect: 3,
        minSelect: 0,
        cascadeDelete: false,
      })
    );
    app.save(tow);
  },
  (app) => {
    const tow = app.findCollectionByNameOrId("tow_requests");
    try {
      tow.fields.removeByName("candidate_drivers");
    } catch (_) {}
    app.save(tow);
  }
);
