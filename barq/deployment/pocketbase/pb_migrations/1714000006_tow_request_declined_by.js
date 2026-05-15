/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");

    c.fields.add(
      new RelationField({
        id: "rel_tow_declined_by",
        name: "declined_by",
        collectionId: "_pb_users_auth_",
        cascadeDelete: false,
        maxSelect: 999,
        minSelect: 0,
        required: false,
      })
    );

    app.save(c);
  },
  (app) => {
    const c = app.findCollectionByNameOrId("tow_requests");
    const declined = c.fields.getByName("declined_by");
    if (declined) {
      c.fields.removeById(declined.id);
      app.save(c);
    }
  }
);
